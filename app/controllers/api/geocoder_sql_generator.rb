# encoding: utf-8

class GeocoderSqlGenerator
  def get(kind, query)
    case kind
      when 'namedplaces'
        #TODO there are several possible formats for this query
        "SELECT (geocode_namedplace(#{query})).*"
      when 'admin0'
        "SELECT (geocode_admin0_polygons(#{query})).*"
      when 'ipaddress'
        "WITH geo_function AS (SELECT (geocode_ip(#{query})).*) SELECT q, geom as the_geom, success FROM geo_function"
      when 'admin1'
        "SELECT (geocode_admin1_polygons(#{query})).*"
      when 'postalcode'
        "SELECT (geocode_postalcode_points(#{query})).*"
      else
        raise 'Invalid kind'
    end
  end
end
