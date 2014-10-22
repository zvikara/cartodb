# encoding: UTF-8

require 'spec_helper'

describe "Geocoder Direct API" do

  before(:all) do
    @user = create_user(username: 'test')
  end

  before(:each) do
    CartoDB::NamedMapsWrapper::NamedMaps.any_instance.stubs(:get).returns(nil)
    delete_user_data @user
    host! 'test.localhost.lan'
  end

  after(:all) do
    @user.destroy
  end

  describe 'GET /api/v1/geocoder' do
    it 'geocodes admin0' do
      params = {
        :api_key => @user.api_key,
        :kind => 'admin0',
        :q => '["Japan", "China"]'
      }
      get_json api_v1_geocoder_geocode_url(params) do |response|
        response.status.should be_success
        response.headers['Content-Type'].should eq 'application/json; charset=utf-8'
        response.body[:total_rows].should eq 2
        response.body[:fields].should == {
          'q' => {'type' => 'string'}, 'geom' => {'type' => 'geometry'}, 'success' => {'type' => 'boolean'}
        }
      end
    end

    it 'geocodes ipaddress' do
      params = {
        :api_key => @user.api_key,
        :kind => 'ipaddress',
        :q => '["179.60.192.33"]'
      }
      get_json api_v1_geocoder_geocode_url(params) do |response|
        response.status.should be_success
        response.headers['Content-Type'].should eq 'application/json; charset=utf-8'
        response.body[:total_rows].should eq 1
        response.body[:fields].should == {
          'q' => {'type' => 'string'}, 'the_geom' => {'type' => 'geometry'}, 'success' => {'type' => 'boolean'}
        }
      end
    end

    it 'honors format param' do
      params = {
        :api_key => @user.api_key,
        :kind => 'ipaddress',
        :q => '["179.60.192.33"]',
        :format => 'geojson'
      }
      get_json api_v1_geocoder_geocode_url(params) do |response|
        response.status.should be_success
        response.headers['Content-Type'].should eq 'application/vnd.geo+json; charset=utf-8'
      end
    end

  end

end
