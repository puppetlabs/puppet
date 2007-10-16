class Puppet::Network::HTTP::WEBrickREST
    def initialize(args = {})
        raise ArgumentError unless args[:server]
        raise ArgumentError if !args[:handlers] or args[:handlers].empty?
        
        @models = {}
        args[:handlers].each do |handler|
            @models[handler] = find_model_for_handler(handler)
        end
    end

  private

    def find_model_for_handler(handler)
        Puppet::Indirector::Indirection.model(handler) || 
            raise(ArgumentError, "Cannot locate indirection [#{handler}].")
    end
end