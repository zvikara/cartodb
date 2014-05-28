namespace :cartodb do
  namespace :db do

    #################
    # LOAD TABLE OIDS
    #################
    desc 'Load table oids'
    task :load_oids => :environment do
      count = User.count
      User.all.each_with_index do |user, i|
        begin
          user.link_outdated_tables
          printf "OK %-#{20}s (%-#{4}s/%-#{4}s)\n", user.username, i, count
        rescue => e
          printf "FAIL %-#{20}s (%-#{4}s/%-#{4}s) #{e.message}\n", user.username, i, count
        end
        #sleep(1.0/5.0)
      end
    end

    desc 'Copy user api_keys from redis to postgres'
    task :copy_api_keys_from_redis => :environment do
      count = User.count
      User.all.each_with_index do |user, i|
        begin
          user.this.update api_key: $users_metadata.HGET(user.key, 'map_key')
          raise 'No API key!!' if user.reload.api_key.blank?
          puts "(#{i+1} / #{count}) OK   #{user.username}"
        rescue => e
          puts "(#{i+1} / #{count}) FAIL #{user.username} #{e.message}"
        end
      end
    end # copy_api_keys_from_redis

    desc 'Rebuild user tables/layers join table'
    task :register_table_dependencies => :environment do
      count = Map.count

      Map.all.each_with_index do |map, i|
        begin
          map.data_layers.each do |layer| 
            layer.register_table_dependencies
            printf "OK (%-#{4}s/%-#{4}s)\n", i, count
          end
        rescue => e
          printf "FAIL (%-#{4}s/%-#{4}s) #{e}\n", i, count
        end
      end
    end

    ########################
    # LOAD CARTODB FUNCTIONS
    ########################
    desc 'Install/upgrade CARTODB SQL functions'
    task :load_functions => :environment do |t, args|
      count = User.count
      execute_on_users_with_index(:load_functions.to_s, Proc.new { |user, i|
          begin
            postgis_present = user.in_database(as: :superuser).fetch(%Q{
              SELECT COUNT(*) AS count FROM pg_extension WHERE extname='postgis'
            }).first[:count] > 0
            topology_present = user.in_database(as: :superuser).fetch(%Q{
              SELECT COUNT(*) AS count FROM pg_extension WHERE extname='postgis_topology'
            }).first[:count] > 0
            triggers_present = user.in_database(as: :superuser).fetch(%Q{
              SELECT COUNT(*) AS count FROM pg_extension WHERE extname='schema_triggers'
            }).first[:count] > 0
            cartodb_present = user.in_database(as: :superuser).fetch(%Q{
              SELECT COUNT(*) AS count FROM pg_extension WHERE extname='cartodb'
            }).first[:count] > 0

            user.in_database(as: :superuser)
              .run(postgis_present ? 'ALTER EXTENSION postgis UPDATE;' : 'CREATE EXTENSION postgis FROM unpackaged;')
            user.in_database(as: :superuser)
              .run(topology_present ? 'ALTER EXTENSION postgis_topology UPDATE;' : 'CREATE EXTENSION postgis_topology FROM unpackaged;')
            user.in_database(as: :superuser)
              .run(triggers_present ? 'ALTER EXTENSION schema_triggers UPDATE;' : 'CREATE EXTENSION schema_triggers;')
            user.in_database(as: :superuser)
              .run(cartodb_present ? 'ALTER EXTENSION cartodb UPDATE;' : 'CREATE EXTENSION cartodb FROM unpackaged;')

            # Temp way of setting dev versions of the extension
            user.in_database(as: :superuser)
              .run("ALTER EXTENSION cartodb UPDATE TO '0.2.0devnext'; ALTER EXTENSION cartodb UPDATE TO '0.2.0dev';")


            user.in_database(as: :superuser).run('SELECT cartodb.cdb_enable_ddl_hooks();')

            printf "OK %-#{20}s (%-#{4}s/%-#{4}s)\n", user.username, i+1, count

            User.terminate_database_connections(user.database_name, user.database_host)
          rescue => e
            printf "FAIL %-#{20}s (%-#{4}s/%-#{4}s) - #{e.message}\n", user.username, i+1, count
          end


      })
    end

    desc 'Load varnish invalidation function'
    task :load_varnish_invalidation_function => :environment do
      count = User.count
      printf "Starting cartodb:db:load_varnish_invalidation_function task for %d users\n", count
      User.all.each_with_index do |user, i|
        begin
          user.create_function_invalidate_varnish
          printf "OK %-#{20}s (%-#{4}s/%-#{4}s)\n", user.username, i+1, count
        rescue => e
          printf "FAIL %-#{20}s (%-#{4}s/%-#{4}s) #{e.message}\n", user.username, i+1, count
        end
        #sleep(1.0/5.0)
      end
    end


    ########################
    # LOAD CARTODB TRIGGERS
    ########################
    desc 'Install/upgrade CARTODB SQL triggers'
    task :load_triggers => :environment do |t, args|
      require_relative '../../app/models/table'

      count = User.count
      User.all.each_with_index do |user, i|
        begin
          user.tables.all.each do |table|
            begin
              # set triggers
              table.set_triggers
            rescue => e
              puts e
              next
            end
          end
          printf "OK %-#{20}s (%-#{4}s/%-#{4}s)\n", user.username, i, count
        rescue => e
          printf "FAIL %-#{20}s (%-#{4}s/%-#{4}s) #{e.message}\n", user.username, i, count
        end
      end
    end
        
    ##############
    # SET DB PERMS
    ##############
    desc "Set DB Permissions"
    task :set_permissions => :environment do
      User.all.each do |user|
        next if !user.respond_to?('database_name') || user.database_name.blank?

        # reset perms
        user.set_database_permissions

        # rebuild public access perms from redis
        user.tables.all.each do |table|
          
          # reset public
          if table.public?
            user.in_database(:as => :superuser).run("GRANT SELECT ON #{table.name} TO #{CartoDB::PUBLIC_DB_USER};")
          end
          
          # reset triggers
          table.set_triggers
        end  
      end
    end

    ##########################
    # SET TRIGGER CHECK QUOTA
    ##########################
    desc 'reset check quota trigger on all user tables'
    task :reset_trigger_check_quota => :environment do |t, args|
      puts "Resetting check quota trigger for ##{User.count} users"
      User.all.each_with_index do |user, i|
        begin
          user.rebuild_quota_trigger
        rescue => exception
          puts "\nERRORED #{user.id} (#{user.username}): #{exception.message}\n"
        end
        if i % 500 == 0
          puts "\nProcessed ##{i} users"
        end
      end
    end

    desc 'reset check quota trigger for a given user'
    task :reset_trigger_check_quota_for_user, [:username] => :environment do |t, args|
      raise 'usage: rake cartodb:db:reset_trigger_check_quota_for_user[username]' if args[:username].blank?
      puts "Resetting trigger check quota for user '#{args[:username]}'"
      user  = User.filter(:username => args[:username]).first
      user.rebuild_quota_trigger
    end

    desc "set users quota to amount in mb"
    task :set_user_quota, [:username, :quota_in_mb] => :environment do |t, args|
      usage = 'usage: rake cartodb:db:set_user_quota[username,quota_in_mb]'
      raise usage if args[:username].blank? || args[:quota_in_mb].blank?

      user  = User.filter(:username => args[:username]).first
      quota = args[:quota_in_mb].to_i * 1024 * 1024
      user.update(:quota_in_bytes => quota)
      
      user.rebuild_quota_trigger
      
      puts "User: #{user.username} quota updated to: #{args[:quota_in_mb]}MB. #{user.tables.count} tables updated."
    end


    #################
    # SET TABLE QUOTA
    #################
    desc "set users table quota"
    task :set_user_table_quota, [:username, :table_quota] => :environment do |t, args|
      usage = "usage: rake cartodb:db:set_user_table_quota[username,table_quota]"
      raise usage if args[:username].blank? || args[:table_quota].blank?
      
      user  = User.filter(:username => args[:username]).first      
      user.update(:table_quota => args[:table_quota].to_i)

      puts "User: #{user.username} table quota updated to: #{args[:table_quota]}"
    end

    desc "set unlimited table quota"
    task :set_unlimited_table_quota, [:username] => :environment do |t, args|
      usage = "usage: rake cartodb:db:set_unlimited_table_quota[username]"
      raise usage if args[:username].blank?
      
      user  = User.filter(:username => args[:username]).first      
      user.update(:table_quota => nil)
                    
      puts "User: #{user.username} table quota updated to: unlimited"
    end


    desc "reset Users table quota to 5"
    task :set_all_users_to_free_table_quota => :environment do
      User.all.each do |user|
        next if !user.respond_to?('database_name') || user.database_name.blank?
        user.update(:table_quota => 5) if user.table_quota.blank?
      end
    end
    
    
    ##################
    # SET ACCOUNT TYPE
    ##################
    desc "Set users account type. DEDICATED or FREE"
    task :set_user_account_type, [:username, :account_type] => :environment do |t, args|
      usage = "usage: rake cartodb:db:set_user_account_type[username,account_type]"
      raise usage if args[:username].blank? || args[:account_type].blank?
      
      user  = User.filter(:username => args[:username]).first      
      user.update(:account_type => args[:account_type])
                    
      puts "User: #{user.username} table account type updated to: #{args[:account_type]}"
    end

    desc "reset all Users account type to FREE"
    task :set_all_users_account_type_to_free => :environment do
      User.all.each do |user|
        next if !user.respond_to?('database_name') || user.database_name.blank?
        user.update(:account_type => 'FREE') if user.account_type.blank?
      end
    end


    ##########################################
    # SET USER PRIVATE TABLES ENABLED/DISABLED
    ##########################################
    desc "set users private tables enabled"
    task :set_user_private_tables_enabled, [:username, :private_tables_enabled] => :environment do |t, args|
      usage = "usage: rake cartodb:db:set_user_private_tables_enabled[username,private_tables_enabled]"
      raise usage if args[:username].blank? || args[:private_tables_enabled].blank?
      
      user  = User.filter(:username => args[:username]).first      
      user.update(:private_tables_enabled => args[:private_tables_enabled])
                    
      puts "User: #{user.username} private tables enabled: #{args[:private_tables_enabled]}"
    end

    desc "reset all Users privacy tables permissions type to false"
    task :set_all_users_private_tables_enabled_to_false => :environment do
      User.all.each do |user|
        next if !user.respond_to?('database_name') || user.database_name.blank?
        user.update(:private_tables_enabled => false) if user.private_tables_enabled.blank?
      end
    end

    desc "Update test_quota trigger"
    task :update_test_quota_trigger => :environment do
      User.all.each do |user|
        user.rebuild_quota_trigger
      end
    end

    desc "update created_at and updated_at to correct type and add the default value to now"
    task :update_timestamp_fields => :environment do
      User.all.each do |user|
        next if !user.respond_to?('database_name') || user.database_name.blank?
        puts "user => " + user.username
        user.in_database do |user_database|
          user.tables.all.each do |table|
            table.normalize_timestamp_field!(:created_at, user_database)
            table.normalize_timestamp_field!(:updated_at, user_database)
          end
        end
      end
    end

    desc 'update the old cache trigger which was using redis to the varnish one'
    task :update_cache_trigger => :environment do
      User.all.each do |user|
        puts 'Update cache trigger => ' + user.username
        next if !user.respond_to?('database_name') || user.database_name.blank?
        user.in_database do |user_database|
          user.tables.all.each do |table|
            puts "\t=> #{table.name} updated"
            begin
              table.set_trigger_cache_timestamp
            rescue => e
              puts "\t=> [ERROR] #{table.name}: #{e.inspect}"
            end                
          end
        end
      end
    end

    desc 'Runs the specified CartoDB migration script'
    task :migrate_to, [:version] => :environment do |t, args|
      usage = 'usage: rake cartodb:db:migrate_to[version]'
      raise usage if args[:version].blank?
      require Rails.root.join 'lib/cartodb/generic_migrator.rb'

      CartoDB::GenericMigrator.new(args[:version]).migrate!
    end
    
    desc 'Undo migration changes USE WITH CARE'
    task :rollback_migration, [:version] => :environment do |t, args|
      usage = 'usage: rake cartodb:db:rollback_migration[version]'
      raise usage if args[:version].blank?
      require Rails.root.join 'lib/cartodb/generic_migrator.rb'

      CartoDB::GenericMigrator.new(args[:version]).rollback!
    end
    
    desc 'Save users metadata in redis'
    task :save_users_metadata => :environment do
      User.all.each do |u|
        u.save_metadata
      end
    end

    # Executes a ruby code proc/block on all existing users, outputting some info
    # @param task_name string
    # @param block Proc
    # @example:
    # execute_on_users_with_index(:populate_new_fields.to_s, Proc.new { |user, i| ... })
    def execute_on_users_with_index(task_name, block)
      count = User.count
      puts "\n>Running #{task_name} for #{count} users"
      User.all.each_with_index do |user, i|
        puts "#{user.id} (#{user.username}) ##{i}"
        block.call(user, i)
      end
      puts ">Finished #{task_name}\n"
    end #execute_on_users_with_index

  end
end
