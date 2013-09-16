# encoding: utf-8
require 'sequel'
require 'rack/test'
require_relative '../../spec_helper'
require_relative '../../../app/controllers/api/json/wms_controller'

def app
  CartoDB::Application.new
end

describe Api::Json::WmsController do
  include Rack::Test::Methods

  before(:all) do
    @user = create_user(
      username: 'test',
      email:    'client@example.com',
      password: 'clientex'
    )
    @user.set_map_key
    @api_key = @user.get_map_key

    delete_user_data @user
    @headers = { 
      'CONTENT_TYPE'  => 'application/json',
      'HTTP_HOST'     => 'test.localhost.lan'
    }
  end

  describe 'GET /api/v2/wms' do
    it 'returns WMS capabilities for a WMS server url' do
      @endpoint     = "http://basemap.nationalmap.gov" +
                      "/arcgis/services/USGSImageryTopo/MapServer/WMSServer"
      @query_params = "?service=WMS&request=GetCapabilities"
      @url          = CGI.escape(@endpoint + @query_params)

      get "/api/v2/wms?url=#{@url}&api_key=#{@api_key}", {}, @headers
      last_response.status.should == 200
      representation = JSON.parse(last_response.body)
      representation.fetch('server').should_not be_nil
      representation.fetch('formats').should_not be_empty
      representation.fetch('layers').should_not be_empty
    end
  end
end
