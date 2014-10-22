# encoding: UTF-8
require_relative 'geocoder_sql_generator.rb'

describe GeocoderSqlGenerator do

  before(:all) do
    @sql_generator = GeocoderSqlGenerator.new
  end

  
  describe :get do

    #TODO there are several formats for this, take them into account
    it 'gets the correct query for namedplaces' do
      q = "Array['sunapee'], 'USA'"
      @sql_generator.get('namedplaces', q).should == "SELECT (geocode_namedplace(Array['sunapee'], 'USA')).*"
    end

    it 'gets the correct query for admin0' do
      q = "Array['Japan', 'China']"
      @sql_generator.get('admin0', q).should == "SELECT (geocode_admin0_polygons(Array['Japan', 'China'])).*"
    end

    it 'gets the correct query for admin1' do
      q = "Array['New Jersey', 'Comunidad de Madrid'], Array['USA', 'Spain']"
      @sql_generator.get('admin1', q).should == "SELECT (geocode_admin1_polygons(Array['New Jersey', 'Comunidad de Madrid'], Array['USA', 'Spain'])).*"
    end
    
    it 'gets the correct query for postalcode' do
      #TODO polygons
      q = "Array['10013','11201','03782']"
      expected_sql = "SELECT (geocode_postalcode_points(Array['10013','11201','03782'])).*"
      @sql_generator.get('postalcode', q).should == expected_sql       
    end
    
    it 'gets the correct query for ipaddress' do
      q = "Array['127.0.0.1']"
      @sql_generator.get('ipaddress', q).should == "WITH geo_function AS (SELECT (geocode_ip(Array['127.0.0.1'])).*) SELECT q, geom as the_geom, success FROM geo_function"
    end

    it 'gets the correct query for high-resolution' do
      pending 'TODO high-resolution stuff'
    end

    it 'raises an exception if the query string contains arbitrary sql' do
      pending 'TODO Need to check all inputs before passing anything to SQL API'
    end

    
  end

end
