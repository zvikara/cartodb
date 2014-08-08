Sequel.migration do
  up do
    add_column :users, :old_username, :text, null: true, default: nil
  end

  down do
    drop_column :users, :old_username
  end
end
