class Puppet::Network::HTTP
    def self.new(args = {})
        raise ArgumentError, ":server_type is required" unless args[:server_type]
        obj = class_for_server_type(args[:server_type]).allocate
        obj.send :initialize, args.delete_if {|k,v| k == :server_type }
        obj
    end
    
    class << self
        def class_for_server_type(server_type)
            Class.new
            # TODO:  this will end up probably:     { :webrick => ... }
            
        end
        private :class_for_server_type
    end
end

