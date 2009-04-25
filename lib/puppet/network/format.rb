require 'puppet/provider'
require 'puppet/provider/confiner'

# A simple class for modeling encoding formats for moving
# instances around the network.
class Puppet::Network::Format
    include Puppet::Provider::Confiner

    attr_reader :name, :mime, :weight, :required_methods

    def initialize(name, options = {}, &block)
        @name = name.to_s.downcase.intern

        # This must be done early the values can be used to set required_methods
        define_method_names()

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

        if methods = options[:required_methods]
            @required_methods = methods
            options.delete(:required_methods)
        else
            @required_methods = [:intern_method, :intern_multiple_method, :render_multiple_method, :render_method]
        end

        unless options.empty?
            raise ArgumentError, "Unsupported option(s) %s" % options.keys
        end

        instance_eval(&block) if block_given?
    end

    def intern(klass, text)
        return klass.send(intern_method, text) if klass.respond_to?(intern_method)
        raise NotImplementedError, "%s does not respond to %s; can not intern instances from %s" % [klass, intern_method, mime]
    end

    def intern_multiple(klass, text)
        return klass.send(intern_multiple_method, text) if klass.respond_to?(intern_multiple_method)
        raise NotImplementedError, "%s does not respond to %s; can not intern multiple instances from %s" % [klass, intern_multiple_method, mime]
    end

    def mime=(mime)
        @mime = mime.to_s.downcase
    end

    def render(instance)
        return instance.send(render_method) if instance.respond_to?(render_method)
        raise NotImplementedError, "%s does not respond to %s; can not render instances to %s" % [instance.class, render_method, mime]
    end

    def render_multiple(instances)
        # This method implicitly assumes that all instances are of the same type.
        return instances[0].class.send(render_multiple_method, instances) if instances[0].class.respond_to?(render_multiple_method)
        raise NotImplementedError, "%s does not respond to %s; can not intern multiple instances to %s" % [instances[0].class, render_multiple_method, mime]
    end

    def required_methods_present?(klass)
        [:intern_method, :intern_multiple_method, :render_multiple_method].each do |name|
            return false unless required_method_present?(name, klass, :class)
        end

        return false unless required_method_present?(:render_method, klass, :instance)

        return true
    end

    def supported?(klass)
        suitable? and required_methods_present?(klass)
    end

    def to_s
        "Puppet::Network::Format[%s]" % name
    end

    private

    attr_reader :intern_method, :render_method, :intern_multiple_method, :render_multiple_method

    def define_method_names
        @intern_method = "from_%s" % name
        @render_method = "to_%s" % name
        @intern_multiple_method = "from_multiple_%s" % name
        @render_multiple_method = "to_multiple_%s" % name
    end

    def required_method_present?(name, klass, type)
        return true unless required_methods.include?(name)

        method = send(name)

        if type == :class
            has_method = klass.respond_to?(method)
            message = "class does not respond to %s" % method
        else
            has_method = klass.instance_methods.include?(method)
            message = "class instances do not respond to %s" % method
        end

        return true if has_method

        Puppet.debug "Format %s not supported for %s; %s" % [name, klass, message]
        return false
    end
end
