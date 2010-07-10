class AddEnvironmentToHost < ActiveRecord::Migration
  def self.up
    add_column :hosts, :environment, :string unless ActiveRecord::Base.connection.columns(:hosts).collect {|c| c.name}.include?("environment")
  end

  def self.down
    remove_column :hosts, :environment if ActiveRecord::Base.connection.columns(:hosts).collect {|c| c.name}.include?("environment")
  end
end
