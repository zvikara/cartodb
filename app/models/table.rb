# coding: UTF-8
# Proxies management of a table in the users database
require 'forwardable'
require_relative './table/column_typecaster'
require_relative './table/privacy_manager'
require_relative './table/relator'
require_relative './visualization/member'

class Table < Sequel::Model(:user_tables)
  extend Forwardable

  # Table constants
  PRIVATE = 0
  PUBLIC  = 1
  CARTODB_COLUMNS = %W{ cartodb_id created_at updated_at the_geom }
  THE_GEOM_WEBMERCATOR = :the_geom_webmercator
  THE_GEOM = :the_geom
  RESERVED_COLUMN_NAMES = %W{ oid tableoid xmin cmin xmax cmax ctid ogc_fid }
  PUBLIC_ATTRIBUTES = { 
    :id => :id, :name => :name, :privacy => :privacy_text, :schema => :schema,
    :updated_at => :updated_at, :rows_counted => :rows_estimated,
    :table_size => :table_size, :map_id => :map_id, :description => :description,
    :geometry_types => :geometry_types, :table_visualization => :table_visualization,
    :dependent_visualizations     => :serialize_dependent_visualizations,
    :non_dependent_visualizations => :serialize_non_dependent_visualizations
  }

  DEFAULT_THE_GEOM_TYPE = "geometry"

  many_to_one :map
  many_to_many :layers,
                join_table: :layers_user_tables,
                left_key: :user_table_id, right_key: :layer_id,
                reciprocal: :user_tables
  plugin :association_dependencies, :map => :destroy, layers: :nullify
  plugin :dirty

  def_delegators :relator, *CartoDB::Table::Relator::INTERFACE

  attr_accessor :force_schema, :the_geom_type, :new_table,
                :keep_user_database_table, :migrate_existing_table
  

  def public_values(options = {})
    selected_attrs = if options[:except].present?
      PUBLIC_ATTRIBUTES.select { |k, v| !options[:except].include?(k.to_sym) }
    else
      PUBLIC_ATTRIBUTES
    end

    Hash[selected_attrs.map{ |k, v| [k, (self.send(v) rescue self[v].to_s)] }]
  end

  def geometry_types
    owner.in_database[<<-SQL
      SELECT DISTINCT ST_GeometryType(the_geom) FROM (
        SELECT the_geom
        FROM #{self.name}
        WHERE (the_geom is not null) LIMIT 10
      ) as foo
    SQL
    ].all.map {|r| r[:st_geometrytype] }
  end

  def_dataset_method(:search) do |query|
    conditions = <<-EOS
      to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, '')) @@ plainto_tsquery('english', ?) OR name ILIKE ?
      EOS
    where(conditions, query, "%#{query}%")
  end

  def_dataset_method(:multiple_order) do |criteria|
    return order(:id) if criteria.nil? || criteria.empty?
    order_params = criteria.map do |key, order|
      Sequel.send(order.to_sym, key.to_sym)
    end

    order(*order_params)
  end #multiple_order


  # Ignore mass-asigment on not allowed columns
  self.strict_param_setting = false
  # Allowed columns
  set_allowed_columns(:privacy, :tags, :description)


  def validate
    super

    ## SANITY CHECKS

    # userid and table name tuple must be unique
    validates_unique [:name, :user_id], :message => 'is already taken'

    # tables must have a user
    errors.add(:user_id, "can't be blank") if user_id.blank?

    errors.add(
      :name, "is a reserved keyword, please choose a different one"
    ) if self.name == 'layergroup'

    # privacy setting must be a sane value
    errors.add(:privacy, 'has an invalid value') if privacy != PRIVATE && privacy != PUBLIC

    # Branch if owner dows not have private table privileges
    if !self.owner.try(:private_tables_enabled)

      # If it's a new table and the user is trying to make it private
      if self.new? && privacy == PRIVATE
        errors.add(:privacy, 'unauthorized to create private tables')
      end

      # if the table exists, is private, but the owner no longer has private privalidges
      # basically, this should never happen.
      if !self.new? && privacy == PRIVATE && self.changed_columns.include?(:privacy)
        errors.add(:privacy, 'unauthorized to modify privacy status to private')
      end
    end
  end

  def before_validation
    self.privacy ||= owner.private_tables_enabled ? PRIVATE : PUBLIC
    super
  end

  def before_create
    raise CartoDB::QuotaExceeded if owner.over_table_quota?
    super

    update_updated_at
    self.database_name = owner.database_name
    create_table_in_database unless migrate_existing_table
    cartodbfy
  end

  def before_save
    self.updated_at = table_visualization.updated_at if table_visualization
  end #before_save

  def create_table_in_database
    owner.in_database.create_table self.name do
      column :cartodb_id, "SERIAL PRIMARY KEY"
      String :name
      String :description, :text => true
      DateTime :created_at, :default => Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, :default => Sequel::CURRENT_TIMESTAMP
    end
  end

  def after_save
    super
    update_name_changes
    self.map.save

    manager = CartoDB::Table::PrivacyManager.new(self)
    manager.set_private if privacy == PRIVATE
    manager.set_public  if privacy == PUBLIC
    manager.propagate_to(table_visualization)
    manager.propagate_to_redis_and_varnish if privacy_changed?
    affected_visualizations.each { |visualization|
      manager.propagate_to(visualization)
    } if privacy == PRIVATE
  end

  def after_create
    super
    self.create_default_map_and_layers
    self.create_default_visualization
    self.send_tile_style_request
    owner.in_database(:as => :superuser).run(%Q{
      GRANT SELECT ON "#{self.name}"
      TO #{CartoDB::TILE_DB_USER};
    })
    set_default_table_privacy
    @force_schema = nil
    $tables_metadata.hset key, "user_id", user_id
    self.new_table = true

    if data_import_id
      @data_import = DataImport.find(id: data_import_id)
      @data_import.table_id   = id
      @data_import.table_name = name
      @data_import.save
    end
    add_table_to_stats
  rescue => exception
    CartoDB::Logger.info exception
    CartoDB::Logger.info exception.backtrace
    self.handle_creation_error(exception)
  end

  def before_destroy
    @table_visualization                = table_visualization
    @dependent_visualizations_cache     = dependent_visualizations.to_a
    @non_dependent_visualizations_cache = non_dependent_visualizations.to_a
    super
  end

  def after_destroy
    super
    $tables_metadata.del key
    remove_table_from_stats
    invalidate_varnish_cache
    @dependent_visualizations_cache.each(&:delete)
    @non_dependent_visualizations_cache.each do |visualization|
      visualization.unlink_from(self)
    end
    @table_visualization.delete if @table_visualization

    delete_tile_style
    remove_table_from_user_database unless keep_user_database_table
  end

  def after_commit
    super
    return self unless self.new_table

    update_table_pg_stats
    add_python
    set_trigger_update_updated_at
    set_trigger_cache_timestamp
    set_trigger_check_quota
  rescue => e
    self.handle_creation_error(e)
  end

  def propagate_name_change_to_table_visualization
    table_visualization.name = name
    table_visualization.store
  end #propagate_name_change_to_table_visualization

  def optimize
    owner.in_database(as: :superuser).run("VACUUM FULL #{name}")
  end

  def handle_creation_error(e)
    CartoDB::Logger.info "table#create error", "#{e.inspect}"

    # Remove the table, except if it already exists
    unless self.name.blank? || e.message =~ /relation .* already exists/
      @data_import.log_update("Dropping table #{self.name}") if @data_import
      $tables_metadata.del key

      self.remove_table_from_user_database      
    end

    @data_import.log_error("Import Error: #{e.try(:message)}") if @data_import

    raise e
  end

  def create_default_map_and_layers
    m = Map.create(Map::DEFAULT_OPTIONS.merge(table_id: self.id, user_id: self.user_id))
    self.map_id = m.id
    base_layer = Layer.new(Cartodb.config[:layer_opts]["base"])
    m.add_layer(base_layer)

    data_layer = Layer.new(Cartodb.config[:layer_opts]["data"])
    data_layer.options["table_name"] = self.name
    data_layer.options["user_name"] = self.owner.username
    data_layer.options["tile_style"] = "##{self.name} #{Cartodb.config[:layer_opts]["default_tile_styles"][self.the_geom_type]}"
    data_layer.infowindow ||= {}
    data_layer.infowindow['fields'] = []
    m.add_layer(data_layer)
  end

  def create_default_visualization
    CartoDB::Visualization::Member.new(
      name:         self.name, 
      map_id:       self.map_id, 
      type:         'table', 
      description:  self.description,
      tags:         (tags.split(',') if tags),
      privacy:      (self.privacy == PUBLIC ? 'public' : 'private')
    ).store
  end

  ##
  # Post the style to the tiler
  #
  def send_tile_style_request(data_layer=nil)
    data_layer ||= self.map.data_layers.first
    tile_request('POST', "/tiles/#{self.name}/style?map_key=#{owner.get_map_key}", {
      'style_version' => data_layer.options["style_version"],
      'style'         => data_layer.options["tile_style"]
    })
  rescue => exception
    raise exception if Rails.env.production? || Rails.env.staging?
  end

  def remove_table_from_user_database
    owner.in_database(:as => :superuser) do |user_database|
      begin
        user_database.run("DROP SEQUENCE IF EXISTS cartodb_id_#{oid}_seq")
      rescue => e
        CartoDB::Logger.info "Table#after_destroy error", "maybe table #{self.name} doesn't exist: #{e.inspect}"
      end
      user_database.run(%Q{DROP TABLE IF EXISTS "#{self.name}"})
    end
  end
  ## End of Callbacks

  ##
  # This method removes all the vanish cached objects for the table,
  # tiles included. Use with care O:-)

  def invalidate_varnish_cache
    CartoDB::Varnish.new.purge("obj.http.X-Cache-Channel ~ #{varnish_key}")
    invalidate_cache_for(affected_visualizations) if id && table_visualization
    self
  end

  def invalidate_cache_for(visualizations)
    visualizations.each do |visualization|
      visualization.invalidate_varnish_cache
    end
  end #invalidate_cache_for
  
  def varnish_key
    "^#{self.owner.database_name}:(.*#{self.name}.*)|(table)$"
  end

  # adds the column if not exists or cast it to timestamp field
  def normalize_timestamp(database, column)
    schema = self.schema(reload: true)

    if schema.nil? || !schema.flatten.include?(column)
      database.run(%Q{
        ALTER TABLE "#{name}"
        ADD COLUMN #{column} timestamp
        DEFAULT NOW()
      })
    end

    if schema.present?
      column_type = Hash[schema][column]
      # if column already exists, cast to timestamp value and set default
      if column_type == 'string' && schema.flatten.include?(column)
        success = ms_to_timestamp(database, name, column)
        success = string_to_timestamp(database, name, column) unless success

        database.run(%Q{
          ALTER TABLE "#{name}"
          ALTER COLUMN #{column}
          SET DEFAULT now()
        })
      elsif column_type == 'date'
        database.run(%Q{
          ALTER TABLE "#{name}"
          ALTER COLUMN #{column}
          SET DEFAULT now()
        })
      end
    end
  end #normalize_timestamp_field

  def ms_to_timestamp(database, table, column)
    database.run(%Q{
      ALTER TABLE "#{table}"
      ALTER COLUMN #{column}
      TYPE timestamp without time zone
      USING to_timestamp(#{column}::float / 1000)
    })
    true
  rescue
    false
  end #normalize_ms_to_timestamp

  def string_to_timestamp(database, table, column)
    database.run(%Q{
      ALTER TABLE "#{table}"
      ALTER COLUMN #{column}
      TYPE timestamp without time zone
      USING to_timestamp(#{column}, 'YYYY-MM-DD HH24:MI:SS.MS.US')
    })
    true
  rescue
    false
  end #string_to_timestamp

  def name=(value)
    return if value == self[:name] || value.blank?
    new_name = get_valid_name(value, current_name: self.name)

    # Do not keep track of name changes until table has been saved
    @name_changed_from = self.name if !new? && self.name.present?
    self.invalidate_varnish_cache if self.database_name
    self[:name] = new_name
  end

  def tags=(value)
    return unless value
    self[:tags] = value.split(',').map{ |t| t.strip }.compact.delete_if{ |t| t.blank? }.uniq.join(',')
  end

  def private?
    $tables_metadata.hget(key, "privacy").to_i == PRIVATE
  end

  def public?
    !private?
  end

  def set_default_table_privacy
    self.privacy ||= self.owner.try(:private_tables_enabled) ? PRIVATE : PUBLIC
    save
  end

  # enforce standard format for this field
  def privacy=(value)
    if value == "PRIVATE" || value == PRIVATE || value == PRIVATE.to_s
      self[:privacy] = PRIVATE
    elsif value == "PUBLIC" || value == PUBLIC || value == PUBLIC.to_s
      self[:privacy] = PUBLIC
    end
  end

  def privacy_changed?
    previous_changes.keys.include?(:privacy)
  end #privacy_changed?

  def key
    Table.key(database_name, name)
  rescue
    nil
  end

  def self.key(db_name, table_name)
    "rails:#{db_name}:#{table_name}"
  end

  def sequel
    owner.in_database.from(name)
  end

  def rows_estimated_query(query)
    owner.in_database do |user_database|
      rows = user_database["EXPLAIN #{query}"].all
      est = Integer( rows[0].to_s.match( /rows=(\d+)/ ).values_at( 1 )[0] )
      return est
    end
  end

  def rows_estimated(user=nil)
    user ||= self.owner
    user.in_database["SELECT reltuples::integer FROM pg_class WHERE oid = '#{self.name}'::regclass"].first[:reltuples];
  end

  def rows_counted
    sequel.count
  end

  # Returns table size in bytes
  def table_size(user=nil)
    user ||= self.owner
    @table_size ||= Table.table_size(name, connection: user.in_database)
  end

  def self.table_size(name, options)
    options[:connection]["SELECT pg_total_relation_size(?) as size", name].first[:size] / 2
  rescue Sequel::DatabaseError => e
    nil
  end

  # TODO: make predictable. Alphabetical would be better
  def schema(options = {})
    first_columns     = []
    middle_columns    = []
    last_columns      = []
    owner.in_database.schema(self.name, options.slice(:reload)).each do |column|
      next if column[0] == THE_GEOM_WEBMERCATOR
      col_db_type = column[1][:db_type].starts_with?("geometry") ? "geometry" : column[1][:db_type]
      col = [ column[0],
        (options[:cartodb_types] == false) ? col_db_type : col_db_type.convert_to_cartodb_type,
        col_db_type == "geometry" ? "geometry" : nil,
        col_db_type == "geometry" ? the_geom_type : nil
      ].compact

      # Make sensible sorting for UI
      case column[0]
        when :cartodb_id
          first_columns.insert(0,col)
        when :the_geom
          first_columns.insert(1,col)
        when :created_at, :updated_at
          last_columns.insert(-1,col)
        else
          middle_columns << col
      end
    end

    # sort middle columns alphabetically
    middle_columns.sort! {|x,y| x[0].to_s <=> y[0].to_s}

    # group columns together and return
    (first_columns + middle_columns + last_columns).compact
  end

  def insert_row!(raw_attributes)
    primary_key = nil
    owner.in_database do |user_database|
      schema = user_database.schema(name, :reload => true).map{|c| c.first}
      attributes = raw_attributes.dup.select{ |k,v| schema.include?(k.to_sym) }
      if attributes.keys.size != raw_attributes.keys.size
        raise CartoDB::InvalidAttributes, "Invalid rows: #{(raw_attributes.keys - attributes.keys).join(',')}"
      end
      begin
        primary_key = user_database.from(name).insert(make_sequel_compatible(attributes))
      rescue Sequel::DatabaseError => e
        message = e.message.split("\n")[0]

        # If the type don't match the schema of the table is modified for the next valid type
        invalid_value = (m = message.match(/"([^"]+)"$/)) ? m[1] : nil
        invalid_column = if invalid_value
          attributes.invert[invalid_value] # which is the column of the name that raises error
        else
          if m = message.match(/PGError: ERROR:  value too long for type (.+)$/)
            if candidate = schema(cartodb_types: false).select{ |c| c[1].to_s == m[1].to_s }.first
              candidate[0]
            end
          end
        end

        if invalid_column.nil? || new_column_type != get_new_column_type(invalid_column)
          raise e
        else
          user_database.set_column_type(self.name, invalid_column.to_sym, new_column_type)
          retry
        end
      end
    end
    update_the_geom!(raw_attributes, primary_key)
    primary_key
  end

  def update_row!(row_id, raw_attributes)
    rows_updated = 0
    owner.in_database do |user_database|
      schema = user_database.schema(name, :reload => true).map{|c| c.first}
      attributes = raw_attributes.dup.select{ |k,v| schema.include?(k.to_sym) }
      if attributes.keys.size != raw_attributes.keys.size
        raise CartoDB::InvalidAttributes, "Invalid rows: #{(raw_attributes.keys - attributes.keys).join(',')}"
      end
      if !attributes.except(THE_GEOM).empty?
        begin
          # update row
          rows_updated = user_database.from(name).filter(:cartodb_id => row_id).update(make_sequel_compatible(attributes))
        rescue Sequel::DatabaseError => e
          # If the type don't match the schema of the table is modified for the next valid type
          # TODO: STOP THIS MADNESS
          message = e.message.split("\n")[0]

          invalid_value = (m = message.match(/"([^"]+)"$/)) ? m[1] : nil
          if invalid_value
            invalid_column = attributes.invert[invalid_value] # which is the column of the name that raises error

            if new_column_type = get_new_column_type(invalid_column)
              user_database.set_column_type self.name, invalid_column.to_sym, new_column_type
              retry
            end
          else
            raise e
          end
        end
      else
        if attributes.size == 1 && attributes.keys == [THE_GEOM]
          rows_updated = 1
        end
      end
    end
    update_the_geom!(raw_attributes, row_id)
    rows_updated
  end

  # make all identifiers SEQUEL Compatible
  # https://github.com/Vizzuality/cartodb/issues/331
  def make_sequel_compatible attributes
    attributes.except(THE_GEOM).convert_nulls.each_with_object({}) { |(k, v), h| h[k.identifier] = v }
  end

  def add_column!(options)
    raise CartoDB::InvalidColumnName if RESERVED_COLUMN_NAMES.include?(options[:name]) || options[:name] =~ /^[0-9_]/
    type = options[:type].convert_to_db_type
    cartodb_type = options[:type].convert_to_cartodb_type
    owner.in_database.add_column name, options[:name].to_s.sanitize, type
    self.invalidate_varnish_cache
    return {:name => options[:name].to_s.sanitize, :type => type, :cartodb_type => cartodb_type}
  rescue => e
    if e.message =~ /^PGError/
      raise CartoDB::InvalidType, e.message
    else
      raise e
    end
  end

  def drop_column!(options)
    raise if CARTODB_COLUMNS.include?(options[:name].to_s)
    owner.in_database.drop_column name, options[:name].to_s
    self.invalidate_varnish_cache
  end

  def modify_column!(options)
    old_name  = options.fetch(:name, '').to_s.sanitize
    new_name  = options.fetch(:new_name, '').to_s.sanitize
    raise 'This column cannot be modified' if CARTODB_COLUMNS.include?(old_name.to_s)

    if new_name.present? && new_name != old_name
      rename_column(old_name, new_name)
    end

    column_name = (new_name.present? ? new_name : old_name)
    convert_column_datatype(owner.in_database, name, column_name, options[:type])
    column_type = column_type_for(column_name)
    self.invalidate_varnish_cache
    { name: column_name, type: column_type, cartodb_type: column_type.convert_to_cartodb_type }
  end #modify_column!

  def column_type_for(column_name)
    schema(cartodb_types: false, reload: true).select { |c|
      c[0] == column_name.to_sym 
    }.first[1]
  end #column_type_for

  def column_names_for(db, table_name)
    db.schema(table_name, :reload => true).map{ |s| s[0].to_s }
  end #column_names

  def rename_column(old_name, new_name="")
    raise 'Please provide a column name' if new_name.empty?
    raise 'This column cannot be renamed' if CARTODB_COLUMNS.include?(old_name.to_s)

    if new_name =~ /^[0-9_]/ || RESERVED_COLUMN_NAMES.include?(new_name) || CARTODB_COLUMNS.include?(new_name)
      raise CartoDB::InvalidColumnName, 'That column name is reserved, please choose a different one' 
    end

    owner.in_database do |user_database|
      if column_names_for(user_database, name).include?(new_name)
        raise 'Column already exists' 
      end
      user_database.rename_column(name, old_name.to_sym, new_name.to_sym)
    end
  end #rename_column

  def convert_column_datatype(database, table_name, column_name, new_type)
    CartoDB::ColumnTypecaster.new(
      user_database:  database,
      table_name:     table_name,
      column_name:    column_name,
      new_type:       new_type
    ).run
  end #convert_column_datatype

  def records(options = {})
    rows = []
    records_count = 0
    page, per_page = CartoDB::Pagination.get_page_and_per_page(options)
    order_by_column = options[:order_by] || "cartodb_id"
    mode = (options[:mode] || 'asc').downcase == 'asc' ? 'asc' : 'desc'
    filters = options.slice(:filter_column, :filter_value).reject{|k,v| v.blank?}.values
    where = "WHERE (#{filters.first})|| '' ILIKE '%#{filters.second}%'" if filters.present?

    owner.in_database do |user_database|
      columns_sql_builder = <<-SQL
      SELECT array_to_string(ARRAY(SELECT '"#{name}"' || '.' || quote_ident(c.column_name)
        FROM information_schema.columns As c
        WHERE table_name = '#{name}'
        AND c.column_name <> 'the_geom_webmercator'
        ), ',') AS column_names
      SQL

      column_names = user_database[columns_sql_builder].first[:column_names].split(',')
      if the_geom_index = column_names.index("\"#{name}\".the_geom")
        column_names[the_geom_index] = <<-STR
            CASE
            WHEN GeometryType(the_geom) = 'POINT' THEN
              ST_AsGeoJSON(the_geom,8)
            WHEN (the_geom IS NULL) THEN
              NULL
            ELSE
              'GeoJSON'
            END the_geom
        STR
      end
      select_columns = column_names.join(',')

      # Counting results can be really expensive, so we estimate
      #
      # See https://github.com/Vizzuality/cartodb/issues/716
      #
      max_countable_rows = 65535 # up to this number we accept to count
      rows_count = 0
      rows_count_is_estimated = true
      if filters.present?
        query = "SELECT cartodb_id as total_rows FROM "#{name}" #{where} "
        rows_count = rows_estimated_query(query)
        if rows_count <= max_countable_rows
          query = "SELECT COUNT(cartodb_id) as total_rows FROM "#{name}" #{where} "
          rows_count = user_database[query].get(:total_rows)
          rows_count_is_estimated = false
        end
      else
        rows_count = rows_estimated
        if rows_count <= max_countable_rows
          rows_count = rows_counted
          rows_count_is_estimated = false
        end
      end

      # If we force to get the name from an schema, we avoid the problem of having as
      # table name a reserved word, such 'as'
      #
      # NOTE: we fetch one more row to verify estimated rowcount is not short
      #
      rows = user_database[%Q{SELECT #{select_columns} FROM "#{name}" #{where} ORDER BY \"#{order_by_column}\" #{mode} LIMIT #{per_page}+1 OFFSET #{page}}].all
      CartoDB::Logger.info "Query", "fetch: #{rows.length}"

      # Tweak estimation if needed
      fetched = rows.length
      fetched += page if page

      have_more = rows.length > per_page
      rows.pop if have_more

      records_count = rows_count
      if rows_count_is_estimated
        if have_more
          records_count = fetched > rows_count ? fetched : rows_count
        else
          records_count = fetched
        end
      end

      # TODO: cache row count !!
      # See https://github.com/Vizzuality/cartodb/issues/459


    end
    {
      :id         => id,
      :name       => name,
      :total_rows => records_count,
      :rows       => rows
    }
  end

  def record(identifier)
    row = nil
    owner.in_database do |user_database|
      select = if schema.flatten.include?(THE_GEOM)
        schema.select{|c| c[0] != THE_GEOM }.map{|c| %Q{"#{c[0]}"} }.join(',') + ",ST_AsGeoJSON(the_geom,8) as the_geom"
      else
        schema.map{|c| %Q{"#{c[0]}"} }.join(',')
      end
      # If we force to get the name from an schema, we avoid the problem of having as
      # table name a reserved word, such 'as'
      row = user_database["SELECT #{select} FROM public.#{name} WHERE cartodb_id = #{identifier}"].first
    end
    raise if row.nil?
    row
  end

  def run_query(query)
    v = owner.run_query(query)
  end

  def georeference_from!(options = {})
    if !options[:latitude_column].blank? && !options[:longitude_column].blank?
      set_the_geom_column!("point")

      owner.in_database do |user_database|
        user_database.run(<<-GEOREF
        UPDATE "#{self.name}"
        SET the_geom =
          ST_GeomFromText(
            'POINT(' || #{options[:longitude_column]} || ' ' || #{options[:latitude_column]} || ')',#{CartoDB::SRID}
        )
        WHERE
        trim(CAST(#{options[:longitude_column]} AS text)) ~ '^(([-+]?(([0-9]|[1-9][0-9]|1[0-7][0-9])(\.[0-9]+)?))|[-+]?180)$'
        AND
        trim(CAST(#{options[:latitude_column]} AS text)) ~ '^(([-+]?(([0-9]|[1-8][0-9])(\.[0-9]+)?))|[-+]?90)$'
        GEOREF
        )
      end
      schema(:reload => true)
    else
      raise InvalidArgument
    end
  end


  def the_geom_type
    $tables_metadata.hget(key,"the_geom_type") || DEFAULT_THE_GEOM_TYPE
  end

  def the_geom_type=(value)
    the_geom_type_value = case value.downcase
      when "geometry"
        "geometry"
      when "point"
        "point"
      when "line"
        "multilinestring"
      else
        value !~ /^multi/ ? "multi#{value.downcase}" : value.downcase
    end
    raise CartoDB::InvalidGeomType unless CartoDB::VALID_GEOMETRY_TYPES.include?(the_geom_type_value)
    if owner.in_database.table_exists?(name)
      $tables_metadata.hset(key,"the_geom_type",the_geom_type_value)
    else
      self.temporal_the_geom_type = the_geom_type_value
    end
  end

  # if the table is already renamed, we just need to update the name attribute
  def synchronize_name(name)
    self[:name] = name
    save
  end

  def self.find_all_by_user_id_and_tag(user_id, tag_name)
    fetch("select user_tables.*,
                    array_to_string(array(select tags.name from tags where tags.table_id = user_tables.id),',') as tags_names
                        from user_tables, tags
                        where user_tables.user_id = ?
                          and user_tables.id = tags.table_id
                          and tags.name = ?
                        order by user_tables.id DESC", user_id, tag_name)
  end

  def self.find_by_identifier(user_id, identifier)
    col = (identifier =~ /\A\d+\Z/ || identifier.is_a?(Fixnum)) ? 'id' : 'name'

    table = fetch(%Q{
      SELECT *
      FROM user_tables
      WHERE user_tables.user_id = ?
      AND user_tables.#{col} = ?},
      user_id, identifier
    ).first
    raise RecordNotFound if table.nil?
    table
  end

  def self.find_by_subdomain(subdomain, identifier)
    if user = User.find(:username => subdomain)
      Table.find_by_identifier(user.id, identifier)
    end
  end

  def oid
    @oid ||= owner.in_database["SELECT '#{self.name}'::regclass::oid"].first[:oid]
  end

  # DB Triggers and things
  # TODO: move to user (is db-wide, not table-wide)
  def add_python
    owner.in_database(:as => :superuser).run(<<-SQL
      CREATE OR REPLACE PROCEDURAL LANGUAGE 'plpythonu' HANDLER plpython_call_handler;
    SQL
    )
  end

  def has_trigger? trigger_name
    owner.in_database(:as => :superuser).select('trigger_name').from(:information_schema__triggers)
      .where(:event_object_catalog => owner.database_name,
             :event_object_table => self.name,
             :trigger_name => trigger_name).count > 0
  end

  def has_index? index_name
    self.pg_indexes.include? index_name.to_s
  end

  def pg_indexes
    owner.in_database(:as => :superuser).select(:indexname)
      .from(:pg_indexes).where(:tablename => self.name)
      .all.map { |t| t[:indexname] }
  end

  def set_trigger_the_geom_webmercator
    self.cartodbfy
    # this would really belong in a migration
    owner.in_database(:as => :superuser).run('
      DROP TRIGGER IF EXISTS update_the_geom_webmercator_trigger ON "#{self.name}";
    ')
  end

  def set_trigger_update_updated_at
    self.cartodbfy
    # this would really belong in a migration
    owner.in_database(:as => :superuser).run(%Q{
      DROP TRIGGER IF EXISTS update_updated_at_trigger ON #{name};
    })
  end

  # move to C
  def set_trigger_cache_timestamp

    varnish_host = Cartodb.config[:varnish_management].try(:[],'host') || '127.0.0.1'
    varnish_port = Cartodb.config[:varnish_management].try(:[],'port') || 6082
    varnish_timeout = Cartodb.config[:varnish_management].try(:[],'timeout') || 5
    varnish_critical = Cartodb.config[:varnish_management].try(:[],'critical') == true ? 1 : 0
    varnish_retry = Cartodb.config[:varnish_management].try(:[],'retry') || 5
    purge_command = Cartodb::config[:varnish_management]["purge_command"]

    owner.in_database(:as => :superuser).run(<<-TRIGGER
    CREATE OR REPLACE FUNCTION update_timestamp() RETURNS trigger AS
    $$
        critical = #{varnish_critical}
        timeout = #{varnish_timeout}
        retry = #{varnish_retry}

        client = GD.get('varnish', None)

        while True:

          if not client:
              try:
                import varnish
                client = GD['varnish'] = varnish.VarnishHandler(('#{varnish_host}', #{varnish_port}, timeout))
              except Exception as err:
                plpy.warning('Varnish connection error: ' +  str(err))
                # NOTE: we won't retry on connection error
                if critical:
                  plpy.error('Varnish connection error: ' +  str(err))
                break

          try:
            table_name = TD["table_name"]
            client.fetch('#{purge_command} obj.http.X-Cache-Channel ~ "^#{self.database_name}:(.*%s.*)|(table)$"' % table_name)
            break
          except Exception as err:
            plpy.warning('Varnish fetch error: ' + str(err))
            client = GD['varnish'] = None # force reconnect
            if not retry:
              if critical:
                plpy.error('Varnish fetch error: ' +  str(err))
              break
            retry -= 1 # try reconnecting
    $$
    LANGUAGE 'plpythonu' VOLATILE;

    DROP TRIGGER IF EXISTS cache_checkpoint ON "#{self.name}";
    CREATE TRIGGER cache_checkpoint BEFORE UPDATE OR INSERT OR DELETE OR TRUNCATE ON "#{self.name}" EXECUTE PROCEDURE update_timestamp();

    DROP TRIGGER IF EXISTS track_updates ON "#{self.name}";
    CREATE trigger track_updates
      AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON "#{self.name}"
      FOR EACH STATEMENT
      EXECUTE PROCEDURE cdb_tablemetadata_trigger();

TRIGGER
    )
  end

  # move to C
  def update_table_pg_stats
    owner.in_database[%Q{ANALYZE "#{self.name}";}]
  end

  def cartodbfy
    owner.in_database(:as => :superuser).run("SELECT CDB_CartodbfyTable('#{self.name}')")
  end

  # Set quota checking trigger for this table
  def set_trigger_check_quota
    self.cartodbfy
  end

  def owner
    @owner ||= User.where(id: self.user_id).first
  end

  def table_style
    self.map.data_layers.first.options['tile_style']
  end

  def table_style_from_redis
    $tables_metadata.get("map_style|#{self.database_name}|#{self.name}")
  end

  def data_last_modified
    owner.in_database.select(:updated_at)
      .from(:cdb_tablemetadata)
      .where(tabname: "'#{self.name}'::regclass".lit).first[:updated_at]
  rescue
    nil
  end

  def privacy_text
    self.private? ? 'PRIVATE' : 'PUBLIC'
  end

  def relator
    @relator ||= CartoDB::Table::Relator.new(Rails::Sequel.connection, self)
  end #relator

  private

  def update_updated_at
    self.updated_at = Time.now
  end

  def update_updated_at!
    update_updated_at && save_changes
  end

  def get_valid_name(name, options={})
    name_candidates = [] 
    name_candidates = self.owner.tables.select_map(:name) if owner

    options.merge!(name_candidates: name_candidates)
    Table.get_valid_table_name(name, options)
  end

  # Gets a valid postgresql table name for a given database
  # See http://www.postgresql.org/docs/9.1/static/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS
  def self.get_valid_table_name(name, options = {})
    # Initial name cleaning
    name = name.to_s.strip.downcase
    name = 'untitled_table' if name.blank?

    # Valid names start with a letter or an underscore
    name = "table_#{name}" unless name[/^[a-z_]{1}/]

    # Subsequent characters can be letters, underscores or digits
    name = name.gsub(/[^a-z0-9]/,'_').gsub(/_{2,}/, '_')

    # Postgresql table name limit
    name = name[0..45]

    return name if name == options[:current_name]
    # We don't want to use an existing table name
    existing_names = options[:name_candidates] || options[:connection]["select relname from pg_stat_user_tables WHERE schemaname='public'"].map(:relname)
    existing_names = existing_names + User::SYSTEM_TABLE_NAMES
    rx = /_(\d+)$/
    count = name[rx][1].to_i rescue 0
    while existing_names.include?(name)
      count = count + 1
      suffix = "_#{count}"
      name = name[0..62-suffix.length]
      name = name[rx] ? name.gsub(rx, suffix) : "#{name}#{suffix}"
    end

    # Re-check for duplicated underscores
    return name.gsub(/_{2,}/, '_')
  end

  def get_new_column_type(invalid_column)
    flatten_cartodb_schema = schema.flatten
    cartodb_column_type = flatten_cartodb_schema[flatten_cartodb_schema.index(invalid_column.to_sym) + 1]
    flatten_schema = schema(:cartodb_types => false).flatten
    column_type = flatten_schema[flatten_schema.index(invalid_column.to_sym) + 1]
    CartoDB::NEXT_TYPE[cartodb_column_type]
  end

  def update_the_geom!(attributes, primary_key)
    return unless attributes[THE_GEOM].present? && attributes[THE_GEOM] != 'GeoJSON'
    # TODO: use this once the server geojson is updated
    # begin
    #   owner.in_database.run("UPDATE #{self.name} SET the_geom = ST_SetSRID(ST_GeomFromGeoJSON('#{attributes[THE_GEOM].sanitize_sql}'),#{CartoDB::SRID}) where cartodb_id = #{primary_key}")
    # rescue => e
    #   raise CartoDB::InvalidGeoJSONFormat
    # end

    geo_json = RGeo::GeoJSON.decode(attributes[THE_GEOM], :json_parser => :json).try(:as_text)
    raise CartoDB::InvalidGeoJSONFormat if geo_json.nil?
    owner.in_database.run(%Q{UPDATE "#{self.name}" SET the_geom = ST_GeomFromText('#{geo_json}',#{CartoDB::SRID}) where cartodb_id = #{primary_key}})
  end

  def update_name_changes
    if @name_changed_from.present? && @name_changed_from != name
      # update metadata records
      reload
      $tables_metadata.rename(Table.key(database_name,@name_changed_from), key)
      owner.in_database.rename_table(@name_changed_from, name)
      propagate_name_change_to_table_visualization

      CartoDB::notify_exception(
        CartoDB::GenericImportError.new("Attempt to rename table without layers #{self.name}"), 
        user: owner
      ) if layers.blank?

      layers.each { |layer| layer.rename_table(@name_changed_from, name).save }
    end
    @name_changed_from = nil
  end

  def delete_tile_style
    tile_request('DELETE', "/tiles/#{self.name}/style?map_key=#{owner.get_map_key}")
  rescue => exception
    CartoDB::Logger.info "tilestyle#delete error", "#{exception.inspect}"
  end

  def flush_cache
    tile_request('DELETE', "/tiles/#{self.name}/flush_cache?map_key=#{owner.get_map_key}")
  rescue => exception
    CartoDB::Logger.info "cache#flush error", "#{exception.inspect}"
  end

  def tile_request(request_method, request_uri, form = {})
    uri  = "#{owner.username}.#{Cartodb.config[:tiler_domain]}"
    ip   = '127.0.0.1'
    port = Cartodb.config[:tiler_port] || 80
    http_req = Net::HTTP.new ip, port
    http_req.use_ssl = Cartodb.config[:tiler_protocol] == 'https' ? true : false
    http_req.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request_headers = {'Host' => "#{owner.username}.#{Cartodb.config[:tiler_domain]}"}
    case request_method
      when 'GET'
        http_res = http_req.request_get(request_uri, request_headers)
      when 'POST'
        http_res = http_req.request_post(request_uri, URI.encode_www_form(form), request_headers)
      when 'DELETE'
        extra_delete_headers = {'Depth' => 'Infinity'}
        http_res = http_req.delete(request_uri, request_headers.merge(extra_delete_headers))
      else
    end
    raise "#{http_res.inspect}" unless http_res.is_a?(Net::HTTPOK)
    http_res
  end

  def add_table_to_stats
    CartodbStats.update_tables_counter(1)
    CartodbStats.update_tables_counter_per_user(1, self.owner.username)
    CartodbStats.update_tables_counter_per_host(1)
    CartodbStats.update_tables_counter_per_plan(1, self.owner.account_type)
  end

  def remove_table_from_stats
    CartodbStats.update_tables_counter(-1)
    CartodbStats.update_tables_counter_per_user(-1, self.owner.username)
    CartodbStats.update_tables_counter_per_host(-1)
    CartodbStats.update_tables_counter_per_plan(-1, self.owner.account_type)
  end
end

