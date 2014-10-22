# encoding: utf-8

require 'json'

#TODO move to proper namespace and location
class GeocoderSqlGenerator
  def get(params)
    sql_params = sql_query_args_from(params[:q])
    case params[:kind]
      when 'namedplace'
        #TODO there are several possible formats for this query
        "SELECT (geocode_namedplace(#{sql_params})).*"
      when 'admin0'
        "SELECT (geocode_admin0_polygons(#{sql_params})).*"
      when 'ipaddress'
        "WITH geo_function AS (SELECT (geocode_ip(#{sql_params})).*) SELECT q, geom as the_geom, success FROM geo_function"
      when 'admin1'
        "SELECT (geocode_admin1_polygons(#{sql_params})).*"
      when 'postalcode'
        "SELECT (geocode_postalcode_points(#{sql_params})).*"
      else
        raise 'Invalid kind'
    end
  end

  #TODO move somewhere
  def sql_query_args_from(query_args)
    json_query_args = '[' + query_args + ']'
    args = JSON.parse(json_query_args)
    raise 'Invalid query args' unless args.class == Array
    sql_args = args.reduce([]) do |result, arg|
      case arg
        when Array
          result << 'Array[' + arg.map { |i| "'" + i + "'"}.join(',') + ']'
        when String
          result << "'" + arg + "'"
        else
          raise 'Invalid query args'
      end
    end
    sql_args.join(',')
  end
end
