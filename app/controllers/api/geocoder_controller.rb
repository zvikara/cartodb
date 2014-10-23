# encoding: UTF-8
require Rails.root.join('services', 'sql-api', 'sql_api')
require_relative 'geocoder_sql_generator.rb'

class Api::GeocoderController < ApplicationController
  respond_to :geojson, :json
  before_filter :default_format_geojson

  def default_format_geojson
    request.format = 'geojson' unless params[:format]
  end

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
      format.geojson { render json: @sql_api.parsed_response }
    end
  end

  def available_geometries
    # TODO this is a naive implementation, but it should work ftm
    # see geocodings_controller.rb
    case params[:kind]
      when 'namedplace'
        render json: ['point']
      when 'admin0'
        render json: ['polygon']
      when 'admin1'
        render json: ['polygon']
      when 'postalcode'
        render json: ['point', 'polygon']
      when 'ipaddress'
        render json: ['point']
      when 'high-resolution'
        render json: ['point']
      else
        raise 'Kind not supported'
      end
  end

  def estimation
    case params[:kind]
      when 'namedplace', 'admin0', 'admin1', 'postalcode', 'ipaddress'
        render json: 0
      when 'high-resolution'
      query = ::JSON.parse('[' + params[:q] + ']')
        raise 'Invalid params' unless query[0].class == Array
        render json: query[0].length
      else
        raise 'Kind not supported'
    end
  end

  def credit
    api_authorization_required
    geocoding_data = current_user.data[:geocoding]
    render json: {
      current_monthly_usage: geocoding_data[:monthly_use],
      monthly_quota: geocoding_data[:quota],
      block_price: geocoding_data[:block_price],
      hard_limit: geocoding_data[:hard_limit]
    }
  end

end
