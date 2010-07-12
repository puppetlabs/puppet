class RemoveDuplicatedIndexOnAllTables < ActiveRecord::Migration
  def self.up
    ActiveRecord::Base.connection.tables.each do |t|
      remove_index t.to_s, :id if ActiveRecord::Base.connection.indexes(t).collect {|c| c.columns}.include?("id")
    end
  end

  def self.down
    ActiveRecord::Base.connection.tables.each do |t|
      add_index t.to_s, :id, :integer => true unless ActiveRecord::Base.connection.indexes(t).collect {|c| c.columns}.include?("id")
    end
  end
end
