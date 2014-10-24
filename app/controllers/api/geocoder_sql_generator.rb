# encoding: utf-8

require 'json'

#TODO move to proper namespace and location
module Api
  class GeocoderSqlGenerator
    def get(params)
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
        allowed_types = {
          name: [String, Array]
        }
        sql_params = get_sql_params_from params, allowed_types
        "WITH geo_function AS (SELECT (geocode_admin0_polygons(#{sql_params})).*) SELECT q AS name, geom AS the_geom, success FROM geo_function"
      when 'admin1'
        allowed_types = {
          name: [Array],
          country: [String, Array, NilClass]
        }
        sql_params = get_sql_params_from params, allowed_types
        "WITH geo_function AS (SELECT (geocode_admin1_polygons(#{sql_params})).*) SELECT q AS name, geom AS the_geom, success FROM geo_function"
      when 'postalcode'
        geometry = params[:geometry_type] || 'point'
        case geometry
        when 'point'
          allowed_types = {
            code: [Array],
            country: [String, Array, NilClass]
          }
          sql_params = get_sql_params_from params, allowed_types
          "WITH geo_function AS (SELECT (geocode_postalcode_points(#{sql_params})).*) SELECT q AS postalcode, geom AS the_geom, success FROM geo_function"
        when 'polygon'
          allowed_types = {
            code: [Array],
            country: [String, Array]
          }
          sql_params = get_sql_params_from params, allowed_types
          "WITH geo_function AS (SELECT (geocode_postalcode_polygons(#{sql_params})).*) SELECT q AS postalcode, geom AS the_geom, success FROM geo_function"
        else
          raise 'Invalid geometry'
        end
      when 'ipaddress'
        allowed_types = {
          ip: [Array]
        }
        sql_params = get_sql_params_from params, allowed_types
        "WITH geo_function AS (SELECT (geocode_ip(#{sql_params})).*) SELECT q AS ip, geom AS the_geom, success FROM geo_function"
      else
        raise 'Invalid kind'
      end
    end


    # TODO tests
    def get_sql_params_from(params, allowed_types)
      sql_params = []
      allowed_types.each do |name, types|
        str = params[name]
        begin
          obj = ::JSON.parse(str)
        rescue JSON::ParserError
          # Assume it is a plain string and convert to the right type
          if types.include? String then
            sql_params << "'" + str + "'"
          else
            sql_params << "Array['" + str + "']"
          end
          next
        rescue TypeError => exception
          #TODO this doesn't need to be an exception handling thing
          if str.nil? and types.include? NilClass then
            sql_params << 'null'
            next
          else
            raise exception
          end
        end

        types.include? obj.class or raise 'Invalid param type'

        # Arrays must be of primitive, allowed types
        if obj.class == Array then
          obj.each do |x|
            [String, Fixnum, NilClass].include? x.class or raise "Invalid array, #{name}=#{str}"
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
      when Fixnum
        result << obj.to_s
      when String
        result << "'" + obj + "'"
      when Array
        result << 'Array[' + obj.map { |i| to_sql(i) }.join(',') + ']'
      else
        raise "Invalid query param #{obj}"
      end
      result
    end

  end
end
