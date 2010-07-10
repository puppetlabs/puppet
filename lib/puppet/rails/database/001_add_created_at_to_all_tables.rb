class AddCreatedAtToAllTables < ActiveRecord::Migration
  def self.up
    ActiveRecord::Base.connection.tables.each do |t|
      add_column t.to_s, :created_at, :datetime unless ActiveRecord::Base.connection.columns(t).collect {|c| c.name}.include?("created_at")
    end
  end

  def self.down
    ActiveRecord::Base.connection.tables.each do |t|
      remove_column t.to_s, :created_at unless ActiveRecord::Base.connection.columns(t).collect {|c| c.name}.include?("created_at")
    end
  end
end
