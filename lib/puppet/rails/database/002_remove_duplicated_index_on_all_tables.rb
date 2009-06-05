class RemoveDuplicatedIndexOnAllTables < ActiveRecord::Migration
    def self.up
        ActiveRecord::Base.connection.tables.each do |t|
            if ActiveRecord::Base.connection.indexes(t).collect {|c| c.columns}.include?("id")
                remove_index t.to_s, :id
            end
        end
    end

    def self.down
        ActiveRecord::Base.connection.tables.each do |t|
            unless ActiveRecord::Base.connection.indexes(t).collect {|c| c.columns}.include?("id")
                add_index t.to_s, :id, :integer => true
            end
        end
    end
end
