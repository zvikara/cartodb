#encoding: UTF-8
require Rails.root.join('services', 'sql-api', 'sql_api')

class Api::GeocoderController < ApplicationController
  respond_to :json, :geojson

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
    @sql_api.fetch(sql, params[:format])
    render json: @sql_api.parsed_response
  end

  def geocode_ipaddress
    sql = "WITH geo_function AS (SELECT (geocode_ip(Array['179.60.192.33'])).*) SELECT q, geom as the_geom, success FROM geo_function"
    @sql_api.fetch(sql, params[:format])
    respond_to do |format|
      format.json { render json: @sql_api.parsed_response }
      #TODO add more formats: csv, shp, svg, kml
      format.geojson { render json: @sql_api.parsed_response } #TODO SQL API doc says it is format=GeoJSON
    end
  end

end
