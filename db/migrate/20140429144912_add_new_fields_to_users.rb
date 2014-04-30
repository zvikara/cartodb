class AddNewFieldsToUsers < Sequel::Migration

  def up
    add_column :users, :dedicated_support, :boolean, :default => false
    add_column :users, :remove_logo, :boolean, :default => false
    add_column :users, :hard_geocoding_limit, :boolean, :default => true
    add_column :users, :private_maps_enabled, :boolean, :default => false

    premium_plans = ["CORONELLI", "S", "L", "XS LUMP-SUM", "Coronelli LUMP-SUM", "XS", "Mercator LUMP-SUM", "Dedicated", "S LUMP-SUM", "MERCATOR LUMP-SUM", "MERCATOR", "CORONELLI LUMP-SUM", "Coronelli", "ENTERPRISE", "DEDICATED"]
    regular_plans = ["ACADEMIC", "Academy", "FREE", "ACADEMIC MAGELLAN", "JATORRISMO", "Academic", "Magellan"]

    User.where(account_type: premium_plans).update(dedicated_support: true)
    User.where(account_type: premium_plans).update(remove_logo: true)
    User.where(account_type: premium_plans).update(private_maps_enabled: true)

    User.where("account_type not in ?", regular_plans).update(hard_geocoding_limit: false)
  end

  def down
    drop_column :users, :dedicated_support
    drop_column :users, :remove_logo
    drop_column :users, :hard_geocoding_limit
    drop_column :users, :private_maps_enabled
  end

end
