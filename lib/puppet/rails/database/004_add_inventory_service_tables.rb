class AddInventoryServiceTables < ActiveRecord::Migration
  def self.up
    unless ActiveRecord::Base.connection.tables.include?("inventory_hosts")
      create_table :inventory_hosts do |t|
        t.column :name, :string, :null => false
        t.column :timestamp, :datetime, :null => false
        t.column :updated_at, :datetime
        t.column :created_at, :datetime
      end

      add_index :inventory_hosts, :name, :unique => true
    end

    unless ActiveRecord::Base.connection.tables.include?("inventory_facts")
      create_table :inventory_facts, :id => false do |t|
        t.column :inventory_host_id, :integer, :null => false
        t.column :name, :string, :null => false
        t.column :value, :text, :null => false
      end

      add_index :inventory_facts, [:inventory_host_id, :name], :unique => true
    end
  end

  def self.down
    unless ActiveRecord::Base.connection.tables.include?("inventory_hosts")
      remove_index :inventory_hosts, :name
      drop_table :inventory_hosts
    end

    if ActiveRecord::Base.connection.tables.include?("inventory_facts")
      remove_index :inventory_facts, [:inventory_host_id, :name]
      drop_table :inventory_facts
    end
  end
end
