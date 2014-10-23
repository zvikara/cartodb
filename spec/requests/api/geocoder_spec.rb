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

  describe 'GET /api/v1/geocoder/{kind}' do
    it 'geocodes admin0' do
      params = {
        :kind => 'admin0',
        :q => '["Japan", "China"]'
      }
      get api_v1_geocoder_geocode_url(params) do |response|
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
        :kind => 'ipaddress',
        :q => '["179.60.192.33"]'
      }
      get_json api_v1_geocoder_geocode_url(params) do |response|
        response.status.should be_success
        response.headers['Content-Type'].should eq 'application/vnd.geo+json; charset=utf-8'

        # Bear in mind these tests are quite coupled to data in geocoding account
        response.body.should == {
          :type=>"FeatureCollection",
          :features=>
          [{"type"=>"Feature",
             "geometry"=>{"type"=>"Point", "coordinates"=>[-122.1822, 37.4538]},
             "properties"=>{"q"=>"179.60.192.33", "success"=>true}}]
        }

      end
    end

    it 'honors format param' do
      params = {
        :kind => 'ipaddress',
        :q => '["179.60.192.33"]',
        :format => 'json'
      }
      get_json api_v1_geocoder_geocode_url(params) do |response|
        response.status.should be_success
        response.headers['Content-Type'].should eq 'application/json; charset=utf-8'
      end
    end

  end


  describe 'GET /api/v1/geocoder/{kind}/available_geometries' do
    it 'returns available geometries for different kinds' do

      get_json api_v1_geocoder_available_geometries_url({kind:'namedplace'}) do |response|
        response.status.should be_success
        response.body.should eq ['point']
      end

      get_json api_v1_geocoder_available_geometries_url({kind:'admin0'}) do |response|
        response.status.should be_success
        response.body.should eq ['polygon']
      end

      get_json api_v1_geocoder_available_geometries_url({kind:'admin1'}) do |response|
        response.status.should be_success
        response.body.should eq ['polygon']
      end

      get_json api_v1_geocoder_available_geometries_url({kind:'postalcode'}) do |response|
        response.status.should be_success
        response.body.should eq ['point', 'polygon']
      end
    end
  end


  describe 'GET /api/v1/geocoder/{kind}/estimation' do
    it 'returns 0 for free geocodings' do
      get_json api_v1_geocoder_estimation_url({kind:'namedplace'}) do |response|
        response.status.should be_success
        response.body.should eq 0
      end
      get_json api_v1_geocoder_estimation_url({kind:'namedplace', q:'["Sunapee", "New York City"], "USA"'}) do |response|
        response.status.should be_success
        response.body.should eq 0
      end
      get_json api_v1_geocoder_estimation_url({kind:'admin1', q:'["Sunapee", "New York City"], "USA"'}) do |response|
        response.status.should be_success
        response.body.should eq 0
      end
    end

    it 'returns the number of points for high-resolution' do
      params = {kind:'high-resolution', :q => '["236 5th Avenue","2880 Broadway"],null,["New York City","New York City"],"USA"'}
      get_json api_v1_geocoder_estimation_url(params) do |response|
        response.status.should be_success
        response.body.should eq 2
      end
    end
  end


  describe 'GET /api/v1/geocoder/credit' do
    it 'requires api authentication' do
      get_json api_v1_geocoder_credit_url do |response|
        response.status.should == 406
        response.body.should == {}
      end
    end

    it 'returns a hash with usage, quota, price, hard_limit' do
      params = {api_key: @user.api_key}
      get_json api_v1_geocoder_credit_url(params) do |response|
        response.status.should be_success
        response.body.should == {
          current_monthly_usage: 0,
          monthly_quota: 1000,
          block_price: 1500,
          hard_limit: true
        }
      end
    end
  end

end
