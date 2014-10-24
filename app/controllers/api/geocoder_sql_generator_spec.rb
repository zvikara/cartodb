# encoding: UTF-8
require_relative 'geocoder_sql_generator.rb'

describe Api::GeocoderSqlGenerator do

  before(:all) do
    @sql_generator = Api::GeocoderSqlGenerator.new
  end


  describe :get do

    #TODO there are several formats for this, take them into account
    it 'gets the correct query for namedplaces' do
      params = {
        kind: 'namedplace',
        place: '["sunapee"]',
        country: 'USA'
      }
      @sql_generator.get(params).should ==
        "WITH geo_function AS (SELECT (geocode_namedplace(Array['sunapee'],null,'USA')).*) SELECT q AS place, a1 AS admin1, c AS country, geom AS the_geom, success FROM geo_function"
    end

    it 'gets the correct query for admin0' do
      params = {
        kind: 'admin0',
        name: '["Japan", "China"]'
      }
      @sql_generator.get(params).should ==
        "WITH geo_function AS (SELECT (geocode_admin0_polygons(Array['Japan','China'])).*) SELECT q AS name, geom AS the_geom, success FROM geo_function"
    end

    it 'gets the correct query for admin1' do
      params = {
        kind: 'admin1',
        name: '["New Jersey", "Comunidad de Madrid"]',
        country: '["USA", "Spain"]'
      }
      @sql_generator.get(params).should ==
        "WITH geo_function AS (SELECT (geocode_admin1_polygons(Array['New Jersey','Comunidad de Madrid'],Array['USA','Spain'])).*) SELECT q AS name, geom AS the_geom, success FROM geo_function"
    end

    it 'gets the correct query for postalcode' do
      #TODO polygons
      params = {
        kind: 'postalcode',
        code: '["10013","11201","03782"]'
      }
      expected_sql = "WITH geo_function AS (SELECT (geocode_postalcode_points(Array['10013','11201','03782'],null)).*) SELECT q AS postalcode, geom AS the_geom, success FROM geo_function"

      @sql_generator.get(params).should == expected_sql
    end

    it 'gets the correct query for ipaddress' do
      params = {
        kind: 'ipaddress',
        ip: '127.0.0.1'
      }
      @sql_generator.get(params).should == "WITH geo_function AS (SELECT (geocode_ip(Array['127.0.0.1'])).*) SELECT q AS ip, geom AS the_geom, success FROM geo_function"
    end

    it 'gets the correct query for high-resolution' do
      pending 'TODO high-resolution stuff'
    end

    it 'raises an exception if the query string contains arbitrary sql' do
      pending 'TODO Need to check all inputs before passing anything to SQL API'
    end

  end

end
