require 'puppet/file_collection'

# A simple module for looking up file paths and indexes
# in a file collection.
module Puppet::FileCollection::Lookup
    attr_accessor :line, :file_index

    def file_collection
        Puppet::FileCollection.collection
    end

    def file=(path)
        @file_index = file_collection.index(path)
    end

    def file
        return nil unless file_index
        file_collection.path(file_index)
    end
end
