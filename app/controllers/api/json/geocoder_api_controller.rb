#encoding: UTF-8
require Rails.root.join('services', 'sql-api', 'sql_api')

class Api::Json::GeocoderApiController < Api::ApplicationController

  def initialize
    @sql_api = CartoDB::SQLApi.new(username: 'geocoding')
  end

  def geocode
    case params[:kind]
      when 'admin0'
        geocode_admin0
      when 'ipaddress'
        geocode_ipaddress
      else
        raise 'Invalid kind'
    end
  end

  def geocode_admin0
    sql = "SELECT (geocode_admin0_polygons(#{params[:q]})).*"
    @sql_api.fetch(sql)
    render_jsonp(@sql_api.parsed_response, 200)
  end

  def geocode_ipaddress
    sql = "SELECT (geocode_ip(#{params[:q]})).*"
    @sql_api.fetch(sql)
    render_jsonp(@sql_api.parsed_response, 200)
  end

end
