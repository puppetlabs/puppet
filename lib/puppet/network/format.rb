require 'puppet/provider/confiner'

# A simple class for modeling encoding formats for moving
# instances around the network.
class Puppet::Network::Format
    include Puppet::Provider::Confiner

    attr_reader :name
    attr_accessor :mime

    def initialize(name, options = {}, &block)
        @name = name

        if mime = options[:mime]
            @mime = mime
            options.delete(:mime)
        else
            @mime = "text/%s" % name
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
        raise NotImplementedError
    end

    def intern_multiple(klass, text)
        return klass.send(intern_multiple_method, text) if klass.respond_to?(intern_multiple_method)
        raise NotImplementedError
    end

    def render(instance)
        return instance.send(render_method) if instance.respond_to?(render_method)
        raise NotImplementedError
    end

    def render_multiple(instances)
        # This method implicitly assumes that all instances are of the same type.
        return instances[0].class.send(render_multiple_method, instances) if instances[0].class.respond_to?(render_multiple_method)
        raise NotImplementedError
    end

    def supported?(klass)
        klass.respond_to?(intern_method) and
            klass.respond_to?(intern_multiple_method) and
            klass.respond_to?(render_multiple_method) and
            klass.instance_methods.include?(render_method)
    end

    private

    attr_reader :intern_method, :render_method, :intern_multiple_method, :render_multiple_method
end
