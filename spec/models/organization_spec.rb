require 'spec_helper'

describe Organization do

  before(:all) do
    @user     = create_user :email => 'admin@example.com', :username => 'admin', :password => 'admin123'

    reload_user_data(@user) && @user.reload
  end

  before(:each) do
    CartoDB::NamedMapsWrapper::NamedMaps.any_instance.stubs(:get).returns(nil)
    CartoDB::Varnish.any_instance.stubs(:send_command).returns(true)
  end

  after(:each) do
    Organization.each do |org|
      org.destroy
    end
  end

  describe 'old organization checks' do
    it "should not be valid if his organization doesn't have more seats" do
      organization = FactoryGirl.create(:organization, seats: 1, quota_in_bytes: 12, name: 'org')
      FactoryGirl.create(:user, organization: organization)
      user = User.new
      user.organization = organization
      user.valid?.should be_false
      user.errors.keys.should include(:organization)
    end

    it 'should be valid if his organization has enough seats' do
      organization = FactoryGirl.create(:organization, seats: 1, quota_in_bytes: 12, name: 'org')
      user = User.new
      user.organization = organization
      user.valid?
      user.errors.keys.should_not include(:organization)
    end

    it "should not be valid if his organization doesn't have enough disk space" do
      organization = FactoryGirl.create(:organization, quota_in_bytes: 10.megabytes)
      organization.stubs(:assigned_quota).returns(10.megabytes, name: 'org')
      user = User.new
      user.organization = organization
      user.quota_in_bytes = 1.megabyte
      user.valid?.should be_false
      user.errors.keys.should include(:quota_in_bytes)
    end

    it 'should be valid if his organization has enough disk space' do
      organization = FactoryGirl.create(:organization, quota_in_bytes: 10.megabytes, name: 'org')
      organization.stubs(:assigned_quota).returns(9.megabytes)
      user = User.new
      user.organization = organization
      user.quota_in_bytes = 1.megabyte
      user.valid?
      user.errors.keys.should_not include(:quota_in_bytes)
    end
  end

  describe 'model validations' do
    it 'checks validations are performed correctly' do
      organization = Organization.new

      expect {
        organization.save
      }.to raise_exception Sequel::ValidationFailed

      organization.name = 'wadus1'
      expect {
        organization.save
      }.to raise_exception Sequel::ValidationFailed

      organization.quota_in_bytes = 123
      expect {
        organization.save
      }.to raise_exception Sequel::ValidationFailed

      organization.seats = 5
      organization.save

      organization.valid?.should eq true
      organization.errors.should eq Hash.new

      # Now for a duplicate org name
      organization2 = Organization.new

      organization2.name =  organization.name
      organization2.quota_in_bytes = organization.quota_in_bytes
      organization2.seats = organization.seats
      expect {
        organization2.save
      }.to raise_exception Sequel::ValidationFailed

      organization2.valid?.should eq false
      organization2.errors.should eq ({:name=>["is already taken"]})
    end

  end

  describe 'user organization association' do
    it 'Tests adding a user to an organization' do
      org_name = 'wadus'
      org_quota = 1234567890
      org_seats = 5

      username = @user.username

      organization = Organization.new

      organization.name = org_name
      organization.quota_in_bytes = org_quota
      organization.seats = org_seats
      organization.save

      @user.organization = organization
      @user.save

      @user = User.where(username: username).first
      @user.should_not be nil

      @user.organization_id.should_not eq nil
      @user.organization_id.should eq organization.id
      @user.organization.should_not eq nil
      @user.organization.id.should eq organization.id
      @user.organization.name.should eq org_name
      @user.organization.quota_in_bytes.should eq org_quota
      @user.organization.seats.should eq org_seats
    end
  end

end
