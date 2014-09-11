class CommonData

  def initialize
    @datasets = nil
  end

  def datasets
    if @datasets.nil?

      _datasets = DATASETS_EMPTY

      if is_enabled
        _datasets = get_datasets(get_datasets_json)
      end

      @datasets = _datasets
    end

    @datasets
  end

  private

  def get_datasets(json)
    begin
      rows = JSON.parse(json).fetch('rows', [])
    rescue
      rows = []
    end

    _categories = {}
    _datasets = []

    rows.each { |row|
      category = row['category']
      unless _categories.has_key?(category)
        _categories[category] = {
            :name => category,
            :image_url => row['category_image_url'],
            :count => 0
        }
      end
      _categories[category][:count] += 1

      row.delete('category_image_url')
      row['url'] = export_url(row)
      _datasets << row
    }

    {:datasets => _datasets, :categories => _categories.values}
  end

  def get_datasets_json
    body = nil
    begin
      response = Typhoeus.get(datasets_url, followlocation:true)
      if response.code == 200
        body = response.response_body
      end
    rescue
      body = nil
    end
    body
  end

  def datasets_url
    sql_authenticated_api_url sql_api_url(DATASETS_QUERY, 'v1')
  end

  def export_url(row)
    table_name = row['tabname']
    params = [
        "filename=#{table_name}",
        "format=#{config('format', 'shp')}"
    ]
    cache_endpoint = config('cache_endpoint')
    if cache_endpoint
      params << "buster=#{row['updated_at']}"
      "#{sql_cache_url export_query(table_name)}&#{params.join('&')}"
    else
      "#{sql_api_url export_query(table_name)}&#{params.join('&')}"
    end
  end

  def sql_api_url(query, version='v2')
    "#{config('protocol', 'https')}://#{config('username')}.#{config('host')}#{path_and_querystring(query, version)}"
  end

  def sql_cache_url(query, version='v1')
    "#{config('cache_endpoint')}#{path_and_querystring(query, version)}"
  end

  def path_and_querystring(query, version='v2')
    "/api/#{version}/sql?q=#{URI::encode query}"
  end

  def sql_authenticated_api_url(api_url)
    "#{api_url}&api_key=#{config('api_key')}"
  end

  def export_query(table_name)
    "select * from #{table_name}"
  end

  def is_enabled
    !config('username').nil? && !config('api_key').nil?
  end

  def config(key, default=nil)
    if Cartodb.config[:common_data].present?
      Cartodb.config[:common_data][key].present? ? Cartodb.config[:common_data][key] : default
    else
      default
    end
  end

  DATASETS_EMPTY = {
      :datasets => [],
      :categories => []
  }

  DATASETS_QUERY = <<-query
select
    meta_dataset.name,
    meta_dataset.tabname,
    meta_dataset.description,
    meta_dataset.source,
    meta_dataset.license,
    (
        SELECT reltuples
        FROM pg_class C LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
        WHERE
            nspname NOT IN ('pg_catalog', 'information_schema')
            AND relkind='r'
            AND relname = meta_dataset.tabname
    ) as rows,
    pg_relation_size(meta_dataset.tabname) size,
    extract(epoch from meta_dataset.created_at)::integer * 1e3 created_at,
    (
        select extract(epoch from updated_at)::integer * 1e3
        from cdb_tablemetadata
        where tabname::text = meta_dataset.tabname
    ) as updated_at,
    meta_category.name category,
    meta_category.image_url category_image_url
from meta_dataset, meta_category
where meta_dataset.meta_category_id = meta_category.cartodb_id
  query

end


class CommonDataSingleton
  include Singleton

  def initialize
    @common_data = CommonData.new
    @last_usage = Time.now
  end

  def datasets
    now = Time.now
    if now - @last_usage > (cache_ttl * 60)
      @common_data = CommonData.new
      @last_usage = now
    end
    @common_data.datasets
  end

  def cache_ttl
    ttl = 0
    if Cartodb.config[:common_data].present?
      ttl = Cartodb.config[:common_data]['cache_ttl'] || ttl
    end
    ttl
  end
end
