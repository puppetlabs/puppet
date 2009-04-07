require 'puppet/provider'
require 'puppet/provider/confiner'

# A simple class for modeling encoding formats for moving
# instances around the network.
class Puppet::Network::Format
    include Puppet::Provider::Confiner

    attr_reader :name, :mime, :weight

    def initialize(name, options = {}, &block)
        @name = name.to_s.downcase.intern

        if mime = options[:mime]
            self.mime = mime
            options.delete(:mime)
        else
            self.mime = "text/%s" % name
        end

        if weight = options[:weight]
            @weight = weight
            options.delete(:weight)
        else
            @weight = 5
        end

        unless options.empty?
            raise ArgumentError, "Unsupported option(s) %s" % options.keys
        end

        instance_eval(&block) if block_given?

        @intern_method = "from_%s" % name
        @render_method = "to_%s" % name
        @intern_multiple_method = "from_multiple_%s" % name
        @render_multiple_method = "to_multiple_%s" % name
    end

    def intern(klass, text)
        return klass.send(intern_method, text) if klass.respond_to?(intern_method)
        raise NotImplementedError, "%s can not intern instances from %s" % [klass, mime]
    end

    def intern_multiple(klass, text)
        return klass.send(intern_multiple_method, text) if klass.respond_to?(intern_multiple_method)
        raise NotImplementedError, "%s can not intern multiple instances from %s" % [klass, mime]
    end

    def mime=(mime)
        @mime = mime.to_s.downcase
    end

    def render(instance)
        return instance.send(render_method) if instance.respond_to?(render_method)
        raise NotImplementedError, "%s can not render instances to %s" % [instance.class, mime]
    end

    def render_multiple(instances)
        # This method implicitly assumes that all instances are of the same type.
        return instances[0].class.send(render_multiple_method, instances) if instances[0].class.respond_to?(render_multiple_method)
        raise NotImplementedError, "%s can not intern multiple instances to %s" % [instances[0].class, mime]
    end

    def supported?(klass)
        suitable? and
            klass.respond_to?(intern_method) and
            klass.respond_to?(intern_multiple_method) and
            klass.respond_to?(render_multiple_method) and
            klass.instance_methods.include?(render_method)
    end

    def to_s
        "Puppet::Network::Format[%s]" % name
    end

    private

    attr_reader :intern_method, :render_method, :intern_multiple_method, :render_multiple_method
end
