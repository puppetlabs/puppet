class Puppet::Rails::Database < ActiveRecord::Migration
    require 'sqlite3'

    def self.up
        ActiveRecord::Migration.verbose = false

        create_table :rails_objects do |table|
            table.column :name, :string, :null => false
            table.column :ptype,  :string, :null => false
            table.column :tags, :string
            table.column :file, :string
            table.column :line, :integer
            table.column :host_id, :integer
            table.column :collectable, :boolean
        end

        create_table :rails_parameters do |table|
            table.column :name, :string, :null => false
            table.column :value,  :string, :null => false
            table.column :rails_object_id,  :integer
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
        drop_table :rails_objects
        drop_table :rails_parameters
        drop_table :hosts
    end
end
