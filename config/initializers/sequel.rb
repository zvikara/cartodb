# According to sequel-3.42.0/lib/sequel/adapters/shared/postgres.rb
# these are needed "to use whatever the server defaults are":
#
# The aim is to avoid using SET on connection
# 
Sequel::Postgres.client_min_messages = nil
Sequel::Postgres.force_standard_strings = false
Sequel::Postgres.use_iso_date_format = false
