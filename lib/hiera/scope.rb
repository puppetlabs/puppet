class Hiera
    class Scope
        def initialize(input)
            @input = input
        end

        def [](key)
            @input.lookupvar(key)
        end

        def include?(key)
            @input.lookupvar(key) == ""
        end
    end
end
