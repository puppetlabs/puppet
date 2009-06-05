class AddEnvironmentToHost < ActiveRecord::Migration
    def self.up
        unless ActiveRecord::Base.connection.columns(:hosts).collect {|c| c.name}.include?("environment")
            add_column :hosts, :environment, :string
        end
    end

    def self.down
        if ActiveRecord::Base.connection.columns(:hosts).collect {|c| c.name}.include?("environment")
            remove_column :hosts, :environment
        end
    end
end
