class Puppet::Network::HTTP::WEBrickREST
    def initialize(args = {})
        raise ArgumentError unless args[:server]
        raise ArgumentError unless @handler = args[:handler]
        @model = find_model_for_handler(@handler)
    end

  private

    def find_model_for_handler(handler)
        Puppet::Indirector::Indirection.model(handler) || 
            raise(ArgumentError, "Cannot locate indirection [#{handler}].")
    end
end