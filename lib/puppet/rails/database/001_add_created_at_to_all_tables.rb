class AddCreatedAtToAllTables < ActiveRecord::Migration
    def self.up
        ActiveRecord::Base.connection.tables.each do |t|
            unless ActiveRecord::Base.connection.columns(t).collect {|c| c.name}.include?("created_at")
                add_column t.to_s, :created_at, :datetime
            end
        end
    end

    def self.down
        ActiveRecord::Base.connection.tables.each do |t|
            unless ActiveRecord::Base.connection.columns(t).collect {|c| c.name}.include?("created_at")
                remove_column t.to_s, :created_at
            end
        end
    end
end
