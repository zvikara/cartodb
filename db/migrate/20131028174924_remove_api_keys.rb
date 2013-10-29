Sequel.migration do
  def up
    drop_table :api_keys
  end

  def down
  end
end
