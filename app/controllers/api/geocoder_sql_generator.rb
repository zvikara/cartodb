# encoding: utf-8

class GeocoderSqlGenerator
  def get(kind, query)
    case kind
      when 'admin0'
        "SELECT (geocode_admin0_polygons(#{query})).*"
      when 'ipaddress'
        "WITH geo_function AS (SELECT (geocode_ip(#{query})).*) SELECT q, geom as the_geom, success FROM geo_function"
      else
        raise 'Invalid kind'
    end
  end
end
