# encoding: utf-8

require 'json'

#TODO move to proper namespace and location
class GeocoderSqlGenerator
  def get(params)
    #sql_params = sql_query_args_from(params[:q])
    case params[:kind]
    when 'namedplace'
      # E.g.: place=["Portland", "Portland", "New York City"]&admin1=["Maine", "Oregon", null]&country=["", null, "United States"]
      allowed_types = {
        place: [String, Array],
        admin1: [String, Array, NilClass],
        country: [String, Array, NilClass]
      }
      sql_params = get_sql_params_from params, allowed_types
      "WITH geo_function AS (SELECT (geocode_namedplace(#{sql_params})).*) SELECT q AS place, a1 AS admin1, c AS country, geom AS the_geom, success FROM geo_function"
    when 'admin0'
      begin
        name_object = ::JSON.parse(params[:name])
        name = to_sql(name_object)
      rescue JSON::ParserError
        # Assume it is a plain string
        name = "Array['" + params[:name] + "']"
      end
      #TODO assert it is either a string, null or an array of strings
      #TODO convert to [str] if it is a str
      "WITH geo_function AS (SELECT (geocode_admin0_polygons(#{name})).*) SELECT q as name, geom AS the_geom, success FROM geo_function"
    when 'ipaddress'
      begin
        ip_object = ::JSON.parse(params[:ip])
        ip = to_sql(ip_object)
      rescue JSON::ParserError
        # Assume it is a plain string
        ip = "Array['" + params[:ip] + "']"
      end
      "WITH geo_function AS (SELECT (geocode_ip(#{ip})).*) SELECT q as ip, geom as the_geom, success FROM geo_function"
    when 'admin1'
      "WITH geo_function AS (SELECT (geocode_admin1_polygons(#{sql_params})).*) SELECT q, geom as the_geom, success FROM geo_function"
    when 'postalcode'
      "WITH geo_function AS (SELECT (geocode_postalcode_points(#{sql_params})).*) SELECT q, geom as the_geom, success FROM geo_function"
    else
      raise 'Invalid kind'
    end
  end


  # TODO tests
  def get_sql_params_from(params, allowed_types)
    sql_params = []
    allowed_types.each do |name, types|
      str = params[name]
      obj = ::JSON.parse(str)
      types.include? obj.class or raise 'Invalid param type'

      # Arrays must be of primitive, allowed types
      if obj.class == Array then
        obj.each do |x|
          (types - [Array]).include? x.class or raise "Invalid array, #{name}=#{str}"
        end
      end

      sql_params << to_sql(obj)
    end
    sql_params.join(',')
  end

  # TODO tests
  def to_sql(obj)
    result = ''
    case obj
    when NilClass
      result << 'null'
    when String
      result << "'" + obj + "'"
    when Array
      result << 'Array[' + obj.map { |i| to_sql(i) }.join(',') + ']'
    else
      raise 'Invalid query param'
    end
    result
  end


  #TODO move somewhere
  #TODO this parser is good enough but not perfect: restrict to 1 level arrays, strings and nulls
  #TODO delete (shouldn't be used)
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
