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
        yaml = instance.to_yaml

        yaml = fixup(yaml) unless yaml.nil?
        yaml
    end

    # Yaml monkey-patches Array, so this works.
    def render_multiple(instances)
        yaml = instances.to_yaml

        yaml = fixup(yaml) unless yaml.nil?
        yaml
    end

    # Everything's supported unless you're on 1.8.1
    def supported?(klass)
        RUBY_VERSION != '1.8.1'
    end

    # fixup invalid yaml as per:
    # http://redmine.ruby-lang.org/issues/show/1331
    def fixup(yaml)
        yaml.gsub!(/((?:&id\d+\s+)?!ruby\/object:.*?)\s*\?/) { "? #{$1}" }
        yaml
    end
end

# This is a "special" format which is used for the moment only when sending facts
# as REST GET parameters (see Puppet::Configurer::FactHandler).
# This format combines a yaml serialization, then zlib compression and base64 encoding.
Puppet::Network::FormatHandler.create(:b64_zlib_yaml, :mime => "text/b64_zlib_yaml") do
    require 'base64'

    def use_zlib?
        Puppet.features.zlib? && Puppet[:zlib]
    end

    def requiring_zlib
        if use_zlib?
            yield
        else
            raise Puppet::Error, "the zlib library is not installed or is disabled."
        end
    end

    def intern(klass, text)
        decode(text)
    end

    def intern_multiple(klass, text)
        decode(text)
    end

    def render(instance)
        yaml = instance.to_yaml

        yaml = encode(fixup(yaml)) unless yaml.nil?
        yaml
    end

    def render_multiple(instances)
        yaml = instances.to_yaml

        yaml = encode(fixup(yaml)) unless yaml.nil?
        yaml
    end

    # Because of yaml issue in ruby 1.8.1...
    def supported?(klass)
        RUBY_VERSION != '1.8.1' and use_zlib?
    end

    # fixup invalid yaml as per:
    # http://redmine.ruby-lang.org/issues/show/1331
    def fixup(yaml)
        yaml.gsub!(/((?:&id\d+\s+)?!ruby\/object:.*?)\s*\?/) { "? #{$1}" }
        yaml
    end

    def encode(text)
        requiring_zlib do 
            Base64.encode64(Zlib::Deflate.deflate(text, Zlib::BEST_COMPRESSION))
        end
    end

    def decode(yaml)
        requiring_zlib do 
            YAML.load(Zlib::Inflate.inflate(Base64.decode64(yaml)))
        end
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

Puppet::Network::FormatHandler.create(:pson, :mime => "text/pson", :weight => 10, :required_methods => [:render_method, :intern_method]) do
    confine :true => Puppet.features.pson?

    def intern(klass, text)
        data_to_instance(klass, PSON.parse(text))
    end

    def intern_multiple(klass, text)
        PSON.parse(text).collect do |data|
            data_to_instance(klass, data)
        end
    end

    # PSON monkey-patches Array, so this works.
    def render_multiple(instances)
        instances.to_pson
    end

    # If they pass class information, we want to ignore it.  By default,
    # we'll include class information but we won't rely on it - we don't
    # want class names to be required because we then can't change our
    # internal class names, which is bad.
    def data_to_instance(klass, data)
        if data.is_a?(Hash) and d = data['data']
            data = d
        end
        if data.is_a?(klass)
            return data
        end
        klass.from_pson(data)
    end
end
