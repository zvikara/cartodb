# encoding: utf-8

require_relative '../visualization/member'
require_relative '../../../services/named-maps-api-wrapper/lib/named-maps-wrapper/exceptions'

# Registers User DB table CREATE/UPDATE/DELETE actions so user_tables (and thus Table model) is properly kept in sync.
# Intended to be called (through calls to API table_controller -> registar_xxx) by python script from DDL Triggers.
module CartoDB
  module Table
    class Registar

      ACTION_CREATE = 'CREATE'
      ACTION_UPDATE = 'UPDATE'
      ACTION_REMOVE = 'REMOVE'

      # @param table_owner User
      def initialize(table_owner)
        @table_owner = table_owner
      end

      # @param table_name string
      # @param table_oid integer
      # @return Table
      # @throws RegistarError
      def create(table_name, table_oid)
        table = ::Table.new
        table.sync_from_registar = true
        table.user_id  = @table_owner.id
        table.name     = table_name
        table.table_id = table_oid
        begin
          table.save
        rescue Exception => exception
          CartoDB::Logger.info 'CartoDB::Table::Registar create', "#{exception.inspect}"
          raise RegistarError.new("CartoDB::Table::Registar create #{table_name} #{table_oid} #{exception.message}")
        end
        table
      end

      # @param table_name string
      # @param table_oid integer
      # @return Table
      # @throws RegistarError
      def update(table_name, table_oid)
        table = ::Table.where(table_id: table_oid, user_id: @table_owner.id).first
        raise RegistarError.new("CartoDB::Table::Registar update #{table_name} #{table_oid} Table not found") if table.nil?
        begin
          table.sync_from_registar = true
          table.name = table_name
          table.save
        rescue Exception => exception
          CartoDB::Logger.info 'CartoDB::Table::Registar update', "#{exception.inspect}"
          raise RegistarError.new("CartoDB::Table::Registar update #{table_name} #{table_oid} #{exception.message}")
        end
        table
      end

      # @param table_name string
      # @param table_oid integer
      # @return boolean
      # @throws RegistarError
      def remove(table_name, table_oid)
        table = ::Table.where(table_id: table_oid, user_id: @table_owner.id).first
        raise RegistarError.new("CartoDB::Table::Registar update #{table_name} #{table_oid} Table not found") if table.nil?
        begin
          member = Visualization::Collection.new.fetch({
            user_id:  @table_owner.id,
            type:     Visualization::Member::CANONICAL_TYPE,
            map_id:   table.map_id
          }).first

          return false if member.nil?
          return false unless member.authorize?(@table_owner)
          # Tables are deleted through visualizations always
          member.delete
          @table_owner.update_visualization_metrics
        rescue CartoDB::NamedMapsWrapper::HTTPResponseError => http_exception
          CartoDB::Logger.info 'CartoDB::Table::Registar remove', "#{http_exception.inspect}"
          raise RegistarError.new("CartoDB::Table::Registar remove #{table_name} #{table_oid} #{http_exception.message}")
        rescue CartoDB::NamedMapsWrapper::NamedMapDataError => named_map_exception
          CartoDB::Logger.info 'CartoDB::Table::Registar remove', "#{named_map_exception.inspect}"
          raise RegistarError.new("CartoDB::Table::Registar remove #{table_name} #{table_oid} #{named_map_exception.message}")
        rescue CartoDB::NamedMapsWrapper::NamedMapsDataError => named_maps_exception
          CartoDB::Logger.info 'CartoDB::Table::Registar remove', "#{named_maps_exception.inspect}"
          raise RegistarError.new("CartoDB::Table::Registar remove #{table_name} #{table_oid} #{named_maps_exception.message}")
        rescue Exception => exception
          CartoDB::Logger.info 'CartoDB::Table::Registar remove', "#{exception.inspect}"
          raise RegistarError.new("CartoDB::Table::Registar remove #{table_name} #{table_oid} #{exception.message}")
        end
        true
      end
    end

    class RegistarError < StandardError; end
  end
end

