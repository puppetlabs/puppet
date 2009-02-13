# A simple way to turn file names into singletons,
# so we don't have tons of copies of each file path around.
class Puppet::FileCollection
    require 'puppet/file_collection/lookup'

    def self.collection
        @collection
    end

    def initialize
        @paths = []
        @inverse = {}
    end

    def index(path)
        if i = @inverse[path]
            return i
        else
            @paths << path
            i = @inverse[path] = @paths.length - 1
            return i
        end
    end

    def path(index)
        @paths[index]
    end

    @collection = self.new
end
