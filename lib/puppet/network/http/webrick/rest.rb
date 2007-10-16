class Puppet::Network::HTTP::WEBrickREST
    def initialize(args = {})
        raise ArgumentError unless @server = args[:server]
        raise ArgumentError unless @handler = args[:handler]
        register_handler
    end

  private
    
    def register_handler
        @model = find_model_for_handler(@handler)
        @server.mount('/' + @handler.to_s, self)
        @server.mount('/' + @handler.to_s + 's', self)
    end

    def find_model_for_handler(handler)
        Puppet::Indirector::Indirection.model(handler) || 
            raise(ArgumentError, "Cannot locate indirection [#{handler}].")
    end
end