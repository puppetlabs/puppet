class AddInventoryServiceTables < ActiveRecord::Migration
  def self.up
    unless ActiveRecord::Base.connection.tables.include?("inventory_nodes")
      create_table :inventory_nodes do |t|
        t.column :name, :string, :null => false
        t.column :timestamp, :datetime, :null => false
        t.column :updated_at, :datetime
        t.column :created_at, :datetime
      end

      add_index :inventory_nodes, :name, :unique => true
    end

    unless ActiveRecord::Base.connection.tables.include?("inventory_facts")
      create_table :inventory_facts, :id => false do |t|
        t.column :node_id, :integer, :null => false
        t.column :name, :string, :null => false
        t.column :value, :text, :null => false
      end

      add_index :inventory_facts, [:node_id, :name], :unique => true
    end
  end

  def self.down
    unless ActiveRecord::Base.connection.tables.include?("inventory_nodes")
      remove_index :inventory_nodes, :name
      drop_table :inventory_nodes
    end

    if ActiveRecord::Base.connection.tables.include?("inventory_facts")
      remove_index :inventory_facts, [:node_id, :name]
      drop_table :inventory_facts
    end
  end
end
