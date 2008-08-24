require 'puppet/network/format_handler'

Puppet::Network::FormatHandler.create(:yaml, :mime => "text/yaml") do
    # Yaml doesn't need the class name; it's serialized.
    def intern(klass, text)
        YAML.load(text)
    end

    # Yaml doesn't need the class name; it's serialized.
    def intern_multiple(klass, text)
        YAML.load(text)
    end

    def render(instance)
        instance.to_yaml
    end

    # Yaml monkey-patches Array, so this works.
    def render_multiple(instances)
        instances.to_yaml
    end

    # Everything's supported
    def supported?(klass)
        true
    end
end


Puppet::Network::FormatHandler.create(:marshal, :mime => "text/marshal") do
    # Marshal doesn't need the class name; it's serialized.
    def intern(klass, text)
        Marshal.load(text)
    end

    # Marshal doesn't need the class name; it's serialized.
    def intern_multiple(klass, text)
        Marshal.load(text)
    end

    def render(instance)
        Marshal.dump(instance)
    end

    # Marshal monkey-patches Array, so this works.
    def render_multiple(instances)
        Marshal.dump(instances)
    end

    # Everything's supported
    def supported?(klass)
        true
    end
end

Puppet::Network::FormatHandler.create(:s, :mime => "text/plain")

# A very low-weight format so it'll never get chosen automatically.
Puppet::Network::FormatHandler.create(:raw, :mime => "application/x-raw", :weight => 1) do
    def intern_multiple(klass, text)
        raise NotImplementedError
    end

    def render_multiple(instances)
        raise NotImplementedError
    end

    # LAK:NOTE The format system isn't currently flexible enough to handle
    # what I need to support raw formats just for individual instances (rather
    # than both individual and collections), but we don't yet have enough data
    # to make a "correct" design.
    #   So, we hack it so it works for singular but fail if someone tries it
    # on plurals.
    def supported?(klass)
        true
    end
end
