# encoding: utf-8

class GeocoderSqlGenerator
  def get(params)
    case params[:kind]
      when 'namedplaces'
        #TODO there are several possible formats for this query
        "SELECT (geocode_namedplace(#{params[:q]})).*"
      when 'admin0'
        "SELECT (geocode_admin0_polygons(#{params[:q]})).*"
      when 'ipaddress'
        "WITH geo_function AS (SELECT (geocode_ip(#{params[:q]})).*) SELECT q, geom as the_geom, success FROM geo_function"
      when 'admin1'
        "SELECT (geocode_admin1_polygons(#{params[:q]})).*"
      when 'postalcode'
        "SELECT (geocode_postalcode_points(#{params[:q]})).*"
      else
        raise 'Invalid kind'
    end
  end
end
