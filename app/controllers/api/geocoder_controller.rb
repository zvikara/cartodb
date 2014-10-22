# encoding: UTF-8
require Rails.root.join('services', 'sql-api', 'sql_api')
require_relative 'geocoder_sql_generator.rb'

class Api::GeocoderController < ApplicationController
  respond_to :json, :geojson

  def initialize
    @sql_api = CartoDB::SQLApi.new(username: 'geocoding')
    @sql_generator = GeocoderSqlGenerator.new
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
    sql = @sql_generator.get params[:kind], params[:q]
    @sql_api.fetch(sql, params[:format])
    render json: @sql_api.parsed_response
  end

  def geocode_ipaddress
    sql = @sql_generator.get params[:kind], params[:q]
    @sql_api.fetch(sql, params[:format])
    respond_to do |format|
      format.json { render json: @sql_api.parsed_response }
      #TODO add more formats: csv, shp, svg, kml
      format.geojson { render json: @sql_api.parsed_response } #TODO SQL API doc says it is format=GeoJSON
    end
  end

end
