# A simplistic class for managing the node information itself.
class Puppet::Node
    attr_accessor :name, :classes, :parameters, :environment, :source, :ipaddress, :names
    attr_reader :time

    def initialize(name, options = {})
        @name = name

        # Provide a default value.
        @names = [name]

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

        unless @environment = options[:environment] 
            if env = Puppet[:environment] and env != ""
                @environment = env
            end
        end

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
