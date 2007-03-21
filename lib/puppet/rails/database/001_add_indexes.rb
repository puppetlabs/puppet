class AddIndexes < ActiveRecord::Migration
    INDEXES = {
        :resources => [[:title, :restype], :host_id, :exported],
        :source_files => [:filename, :path],
        :puppet_classes => [:name, :host_id],
        :hosts => [:name, :ip, :updated_at],
        :fact_names => [:name, :host_id],
        #:fact_values => [:value, :fact_name_id],
        #:param_values => [:value, :param_name_id],
        :param_names => [:name, :resource_id],
        :tags => [:name, :updated_at],
        :taggings => [:tag_id, :taggable_id, :taggable_type]
    }

    def self.up
        puts "trying"
        # Add all of our initial indexes
        INDEXES.each do |table, indexes|
            indexes.each do |index|
                if index.to_s =~ /_id/
                    add_index table, index, :integer => true
                else
                    add_index table, index
                end
            end
        end
    end

    def self.down
        INDEXES.each do |table, indexes|
            indexes.each do |index|
                remove_index table, index
            end
        end
    end
end

# $Id$
