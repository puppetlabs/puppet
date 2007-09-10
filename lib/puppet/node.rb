# A simplistic class for managing the node information itself.
class Puppet::Node
    attr_accessor :name, :classes, :parameters, :source, :ipaddress, :names
    attr_reader :time
    attr_writer :environment

    # Do not return environments tha are empty string, and use
    # explicitly set environments, then facts, then a central env
    # value.
    def environment
        unless @environment and @environment != ""
            if env = parameters["environment"] and env != ""
                @environment = env
            elsif env = Puppet[:environment] and env != ""
                @environment = env
            else
                @environment = nil
            end
        end
        @environment
    end

    def initialize(name, options = {})
        @name = name

        # Provide a default value.
        if names = options[:names]
            if names.is_a?(String)
                @names = [names]
            else
                @names = names
            end
        else
            @names = [name]
        end

        if classes = options[:classes]
            if classes.is_a?(String)
                @classes = [classes]
            else
                @classes = classes
            end
        else
            @classes = []
        end

        @parameters = options[:parameters] || {}

        @environment = options[:environment] 

        @time = Time.now
    end

    # Merge the node facts with parameters from the node source.
    # This is only called if the node source has 'fact_merge' set to true.
    def fact_merge(facts)
        facts.each do |name, value|
            @parameters[name] = value unless @parameters.include?(name)
        end
    end
end
