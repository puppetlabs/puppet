require 'puppet/provider'
require 'puppet/provider/confiner'

# A simple class for modeling encoding formats for moving
# instances around the network.
class Puppet::Network::Format
    include Puppet::Provider::Confiner

    attr_reader :name, :mime
    attr_accessor :intern_method, :render_method, :intern_multiple_method, :render_multiple_method, :weight, :required_methods

    def init_attribute(name, default)
        if value = @options[name]
            @options.delete(name)
        else
            value = default
        end
        self.send(name.to_s + "=", value)
    end

    def initialize(name, options = {}, &block)
        @name = name.to_s.downcase.intern

        @options = options

        # This must be done early the values can be used to set required_methods
        define_method_names()

        method_list = {
            :intern_method => "from_%s" % name,
            :intern_multiple_method => "from_multiple_%s" % name,
            :render_multiple_method => "to_multiple_%s" % name,
            :render_method => "to_%s" % name
        }

        init_attribute(:mime, "text/%s" % name)
        init_attribute(:weight, 5)
        init_attribute(:required_methods, method_list.keys)

        method_list.each do |method, value|
            init_attribute(method, value)
        end

        unless @options.empty?
            raise ArgumentError, "Unsupported option(s) %s" % @options.keys
        end

        @options = nil

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

    def define_method_names
        @intern_method = "from_%s" % name
        @render_method = "to_%s" % name
        @intern_multiple_method = "from_multiple_%s" % name
        @render_multiple_method = "to_multiple_%s" % name
    end

    def required_method_present?(name, klass, type)
        return true unless required_methods.include?(name)

        method = send(name)

        return klass.respond_to?(method) if type == :class
        return klass.instance_methods.include?(method)
    end
end
