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
    end
end
