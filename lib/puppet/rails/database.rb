class Puppet::Rails::Database < ActiveRecord::Migration
    require 'sqlite3'

    def self.up
        if ActiveRecord::Migration.respond_to?(:verbose)
            ActiveRecord::Migration.verbose = false
        end

        # 'type' cannot be a column name, apparently
        create_table :rails_resources do |table|
            table.column :title, :string, :null => false
            table.column :restype,  :string, :null => false
            table.column :tags, :string
            table.column :file, :string
            table.column :line, :integer
            table.column :host_id, :integer
            table.column :exported, :boolean
        end

        create_table :rails_parameters do |table|
            table.column :name, :string, :null => false
            table.column :value,  :string, :null => false
            table.column :file, :string
            table.column :line, :integer
            table.column :rails_resource_id,  :integer
        end

        create_table :hosts do |table|
            table.column :name, :string, :null => false
            table.column :ip, :string
            table.column :facts, :string
            table.column :connect, :date
            table.column :success, :date
            table.column :classes, :string
        end
    end

    def self.down
        drop_table :rails_resources
        drop_table :rails_parameters
        drop_table :hosts
    end
end

# $Id$
