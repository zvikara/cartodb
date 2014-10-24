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
        q: '["sunapee"], "USA"'
      }
      @sql_generator.get(params).should ==
        "WITH geo_function AS (SELECT (geocode_namedplace(Array['sunapee'],'USA')).*) SELECT q, geom AS the_geom, success FROM geo_function"
    end

    it 'gets the correct query for admin0' do
      params = {
        kind: 'admin0',
        q: '["Japan", "China"]'
      }
      @sql_generator.get(params).should ==
        "WITH geo_function AS (SELECT (geocode_admin0_polygons(Array['Japan','China'])).*) SELECT q, geom AS the_geom, success FROM geo_function"
    end

    it 'gets the correct query for admin1' do
      params = {
        kind: 'admin1',
        q: '["New Jersey", "Comunidad de Madrid"], ["USA", "Spain"]'
      }
      @sql_generator.get(params).should ==
        "WITH geo_function AS (SELECT (geocode_admin1_polygons(Array['New Jersey','Comunidad de Madrid'],Array['USA','Spain'])).*) SELECT q, geom as the_geom, success FROM geo_function"
    end

    it 'gets the correct query for postalcode' do
      #TODO polygons
      params = {
        kind: 'postalcode',
        q: '["10013","11201","03782"]'
      }
      expected_sql = "WITH geo_function AS (SELECT (geocode_postalcode_points(Array['10013','11201','03782'])).*) SELECT q, geom as the_geom, success FROM geo_function"
      @sql_generator.get(params).should == expected_sql
    end

    it 'gets the correct query for ipaddress' do
      params = {
        kind: 'ipaddress',
        q: '["127.0.0.1"]'
      }
      @sql_generator.get(params).should == "WITH geo_function AS (SELECT (geocode_ip(Array['127.0.0.1'])).*) SELECT q, geom as the_geom, success FROM geo_function"
    end

    it 'gets the correct query for high-resolution' do
      pending 'TODO high-resolution stuff'
    end

    it 'raises an exception if the query string contains arbitrary sql' do
      pending 'TODO Need to check all inputs before passing anything to SQL API'
    end

  end

  describe :sql_query_args_from do
    it 'should convert arrays' do
      json = '["sunapee"], "USA"'
      @sql_generator.sql_query_args_from(json).should == "Array['sunapee'],'USA'"
    end
  end

end
