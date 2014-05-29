# coding: UTF-8
require_relative '../../../models/visualization/presenter'
require_relative '../../../../services/named-maps-api-wrapper/lib/named-maps-wrapper/exceptions'
require_relative '../../../models/table/registar'

class Api::Json::TablesController < Api::ApplicationController
  TABLE_QUOTA_REACHED_TEXT = 'You have reached your table quota'

  ssl_required :show, :create, :update, :destroy

  before_filter :load_table, except: [:create]
  before_filter :set_start_time
  before_filter :link_ghost_tables, only: [:show]

  # Very basic controller method to simply make blank tables
  # All other table creation things are controlled via the imports_controller#create
  def create
    @table = Table.new
    @table.user_id        = current_user.id
    if params[:name]
      @table.name = params[:name]
    else
      @table.name = Table.get_valid_table_name('', {  connection: current_user.in_database })
    end
    @table.description    = params[:description]   if params[:description]
    @table.the_geom_type  = params[:the_geom_type] if params[:the_geom_type]
    @table.force_schema   = params[:schema]        if params[:schema]
    @table.tags           = params[:tags]          if params[:tags]
    @table.import_from_query = params[:from_query]  if params[:from_query]

    if @table.valid? && @table.save
      @table = Table.where(id: @table.id).first
      render_jsonp(@table.public_values, 200, { location: "/tables/#{@table.id}" })
    else
      CartoDB::Logger.info 'Error on tables#create', @table.errors.full_messages
      render_jsonp( { :description => @table.errors.full_messages,
                      :stack => @table.errors.full_messages
                    }, 400)
    end
  rescue CartoDB::QuotaExceeded
    render_jsonp({ errors: [TABLE_QUOTA_REACHED_TEXT]}, 400)
  end

  def show
    return head(404) if @table == nil
    respond_to do |format|
      format.csv do
        send_data @table.to_csv,
          :type => 'application/zip; charset=binary; header=present',
          :disposition => "attachment; filename=#{@table.name}.zip"
      end
      format.shp do
        send_data @table.to_shp,
          :type => 'application/octet-stream; charset=binary; header=present',
          :disposition => "attachment; filename=#{@table.name}.zip"
      end
      format.kml or format.kmz do
        send_data @table.to_kml,
          :type => 'application/vnd.google-earth.kml+xml; charset=binary; header=present',
          :disposition => "attachment; filename=#{@table.name}.kmz"
      end
      format.json do
        render_jsonp(@table.public_values.merge(schema: @table.schema(reload: true)))
      end
    end
  end

  def update
    warnings = []

    # Perform name validations
    # TODO move this to the model!
    unless params[:name].nil?
      if params[:name].downcase != @table.name
        owner = User.select(:id,:database_name,:crypted_password,:quota_in_bytes,:username, :private_tables_enabled, :table_quota).filter(:id => current_user.id).first
        if params[:name] =~ /^[0-9_]/
          raise "Table names can't start with numbers or dashes."
        elsif owner.tables.filter(:name.like(/^#{params[:name]}/)).select_map(:name).include?(params[:name].downcase)
          raise "Table '#{params[:name].downcase}' already exists."
        else
          @table.set_all(:name => params[:name].downcase)
          @table.save(:name)
        end
      end

    end

    @table.set_except(params, :name)
    if params.keys.include?('latitude_column') && params.keys.include?('longitude_column')
      latitude_column  = params[:latitude_column]  == 'nil' ? nil : params[:latitude_column].try(:to_sym)
      longitude_column = params[:longitude_column] == 'nil' ? nil : params[:longitude_column].try(:to_sym)
      @table.georeference_from!(:latitude_column => latitude_column, :longitude_column => longitude_column)
      render_jsonp(@table.public_values.merge(warnings: warnings)) and return
    end
    if @table.update(@table.values.delete_if {|k,v| k == :tags_names}) != false
      @table = Table.where(id: @table.id).first

      render_jsonp(@table.public_values.merge(warnings: warnings))
    else
      render_jsonp({ :errors => @table.errors.full_messages}, 400)
    end
  rescue => e
    CartoDB::Logger.info e.class.name, e.message
    render_jsonp({ :errors => [translate_error(e.message.split("\n").first)] }, 400) and return
  rescue CartoDB::NamedMapsWrapper::HTTPResponseError => exception
    render_jsonp({ errors: { named_maps_api: "Communication error with tiler API. HTTP Code: #{exception.message}" } }, 400)
  rescue CartoDB::NamedMapsWrapper::NamedMapDataError => exception
    render_jsonp({ errors: { named_map: exception } }, 400)
  rescue CartoDB::NamedMapsWrapper::NamedMapsDataError => exception
    render_jsonp({ errors: { named_maps: exception } }, 400)
  end

  def destroy
    @table.destroy
    head :no_content
  rescue CartoDB::NamedMapsWrapper::HTTPResponseError => exception
    render_jsonp({ errors: { named_maps_api: "Communication error with tiler API. HTTP Code: #{exception.message}" } }, 400)
  rescue CartoDB::NamedMapsWrapper::NamedMapDataError => exception
    render_jsonp({ errors: { named_map: exception } }, 400)
  rescue CartoDB::NamedMapsWrapper::NamedMapsDataError => exception
    render_jsonp({ errors: { named_maps: exception } }, 400)
  end

  def registar_add
    action = CartoDB::Table::Registar::ACTION_CREATE
    (render_jsonp({ error: 'missing table_name' }, 400) and return) unless params[:table_name].present?
    (render_jsonp({ error: 'missing table_oid' }, 400) and return) unless params[:table_oid].present?

    registar_notify(action, params[:table_name], params[:table_oid])
    render_jsonp({action: action})
  end

  def registar_update
    action = CartoDB::Table::Registar::ACTION_UPDATE
    (render_jsonp({ error: 'missing table_name' }, 400) and return) unless params[:table_name].present?
    (render_jsonp({ error: 'missing table_oid' }, 400) and return) unless params[:table_oid].present?

    registar_notify(action, params[:table_name], params[:table_oid])
    render_jsonp({action: action})
  end

  def registar_remove
    action = CartoDB::Table::Registar::ACTION_REMOVE
    (render_jsonp({ error: 'missing table_name' }, 400) and return) unless params[:table_name].present?
    (render_jsonp({ error: 'missing table_oid' }, 400) and return) unless params[:table_oid].present?

    registar_notify(action, params[:table_name], params[:table_oid])
    render_jsonp({action: action})
  end

  private

  def registar_notify(action, table_name, table_oid)
    result = nil
    registar = CartoDB::Table::Registar.new(current_user)

    case action
      when CartoDB::Table::Registar::ACTION_CREATE
        result = registar.create(table_name, table_oid)
      when CartoDB::Table::Registar::ACTION_UPDATE
        result = registar.update(table_name, table_oid)
      when CartoDB::Table::Registar::ACTION_REMOVE
        result = registar.remove(table_name, table_oid)
      else
        render_jsonp({ error: 'unknown action' }, 400) and return
    end

    if result
      render_jsonp({action: action})
    else
      render_jsonp({ error: 'invalid result' }, 400)
    end
  rescue CartoDB::Table::RegistarError => exception
    render_jsonp({ error: "#{exception.message}" }, 500)
  end

  def load_table
    rx = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
    if rx.match(params[:id])
      @table = Table.where('user_id = ? AND (name = ? OR id = ?)', current_user.id, params[:id], params[:id]).first
    else
      @table = Table.where(:name => params[:id], :user_id => current_user.id).first
    end
  end

end

