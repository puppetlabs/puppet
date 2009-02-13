# A simple way to turn file names into singletons,
# so we don't have tons of copies of each file path around.
class Puppet::FileCollection
    def initialize
        @paths = []
    end

    def index(path)
        if @paths.include?(path)
            return @paths.index(path)
        else
            @paths << path
            return @paths.length - 1
        end
    end

    def path(index)
        @paths[index]
    end
end
