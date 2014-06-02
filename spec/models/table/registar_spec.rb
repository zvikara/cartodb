# encoding: utf-8
require_relative '../../spec_helper'

describe CartoDB::Table::Registar do
  before do
    quota_in_bytes  = 524288000
    table_quota     = 500
    @user = create_user(
      quota_in_bytes: quota_in_bytes,
      table_quota:    table_quota
    )
  end

  it 'tests registering a new table' do
    registar = CartoDB::Table::Registar.new(@user)

    table_name = 'test_name'

    @user.run_pg_query(%Q{ CREATE TABLE #{table_name} (description VARCHAR); })
    # TODO: Remove manual cartodbfication when DDL triggers are on
    @user.run_pg_query(%Q{ SELECT CDB_CartodbfyTable('#{table_name}'); })

    table_oid = @user.in_database
      .fetch(%Q{ SELECT oid FROM pg_class WHERE relname = '#{table_name}' AND relkind = 'r'; })
      .first[:oid]

    result = registar.create(table_name, table_oid)

    result.nil?.should eq false
    result.id.nil?.should eq false
    result.name.should eq table_name
    result.table_id.should eq table_oid

    table = Table.where(table_id: table_oid).first
    table.nil?.should eq false
    table.id.should eq result.id
    table.name.should eq result.name
    table.table_id.should eq result.table_id
  end

  it 'tests updating an already registered table' do
    registar = CartoDB::Table::Registar.new(@user)

    table_name_initial = 'test_update_ini'
    table_name_renamed = 'test_update_end'

    create_table(name: table_name_initial, user_id: @user.id)
    table_oid = @user.in_database
      .fetch(%Q{ SELECT oid FROM pg_class WHERE relname = '#{table_name_initial}' AND relkind = 'r'; })
      .first[:oid]

    # Run as superadmin to avoid DDL triggers when they are activated
    @user.in_database(as: :superadmin).run(%Q{ ALTER TABLE #{table_name_initial} RENAME TO #{table_name_renamed}; })

    result = registar.update(table_name_renamed, table_oid)

    result.nil?.should eq false
    result.id.nil?.should eq false
    result.name.should eq table_name_renamed
    result.table_id.should eq table_oid

    table = Table.where(table_id: table_oid).first
    table.nil?.should eq false
    table.id.should eq result.id
    table.name.should eq result.name
    table.table_id.should eq result.table_id
  end

  it 'tests removing an already registered table' do
    registar = CartoDB::Table::Registar.new(@user)

    Table.any_instance.stubs(:tile_request).returns true
    #CartoDB::Varnish.any_instance.stubs(:send_command).returns(true)
    CartoDB::NamedMapsWrapper::NamedMaps.any_instance.stubs(:get).returns(nil)

    table_name = 'test_delete'
    create_table(name: table_name, user_id: @user.id)
    table_oid = @user.in_database
      .fetch(%Q{ SELECT oid FROM pg_class WHERE relname = '#{table_name}' AND relkind = 'r'; })
      .first[:oid]

    # Run as superadmin to avoid DDL triggers when they are activated
    @user.in_database(as: :superadmin).run(%Q{ DROP TABLE #{table_name}; })

    result = registar.remove(table_name, table_oid)

    result.should eq true

    table = Table.where(table_id: table_oid).first
    table.nil?.should eq true
  end

  it 'tests exceptions on create/update registering' do
    registar = CartoDB::Table::Registar.new(@user)

    table_name = 'existing_table'
    create_table(name: table_name, user_id: @user.id)
    table_oid = @user.in_database
      .fetch(%Q{ SELECT oid FROM pg_class WHERE relname = '#{table_name}' AND relkind = 'r'; })
      .first[:oid]

    Table.any_instance.stubs(:save).throws StandardError.new('wadus_error')

    expect {
      registar.create('123', 123)
    }.to raise_exception CartoDB::Table::RegistarError

    # Unexisting table
    expect {
      registar.update('123', 123)
    }.to raise_exception CartoDB::Table::RegistarError

    # Existing table, forced error
    expect {
      registar.update(table_name, table_oid)
    }.to raise_exception CartoDB::Table::RegistarError
  end

  it 'tests exceptions on remove register' do
    registar = CartoDB::Table::Registar.new(@user)

    other_user = create_user(quota_in_bytes: 10240000, table_quota: 5)
    table_name_from_other_user = 'others_table'
    create_table(name: table_name_from_other_user, user_id: other_user.id)
    table_oid_from_other_user = other_user.in_database
      .fetch(%Q{ SELECT oid FROM pg_class WHERE relname = '#{table_name_from_other_user}' AND relkind = 'r'; })
      .first[:oid]

    table_name = 'user_table'
    create_table(name: table_name, user_id: @user.id)
    table_oid = @user.in_database
      .fetch(%Q{ SELECT oid FROM pg_class WHERE relname = '#{table_name}' AND relkind = 'r'; })
      .first[:oid]

    # Non-existing vis
    expect {
      registar.remove('wadus', 456)
    }.to raise_exception CartoDB::Table::RegistarError


    # table from other user
    expect {
      registar.remove(table_name_from_other_user, table_oid_from_other_user)
    }.to raise_exception CartoDB::Table::RegistarError

    # Existing table, forced error
    CartoDB::Visualization::Member.any_instance.stubs(:delete).throws StandardError.new('wadus_error')
    expect {
      registar.remove(table_name, table_oid)
    }.to raise_exception CartoDB::Table::RegistarError
  end

end

