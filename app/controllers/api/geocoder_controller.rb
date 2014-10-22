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
    sql = @sql_generator.get params
    @sql_api.fetch(sql, params[:format])
    respond_to do |format|
      #TODO add more formats: csv, shp, svg, kml
      format.json { render json: @sql_api.parsed_response }
      #TODO SQL API doc says it is format=GeoJSON
      format.geojson { render json: @sql_api.parsed_response }
    end
  end

end
