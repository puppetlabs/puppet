class Puppet::Network::Controller
    def initialize(args = {})
        raise ArgumentError, ":indirection is required" unless args[:indirection]
        @indirection = args[:indirection]
        @klass = model_class_from_indirection_name(@indirection)
    end
    
    def find(args = {})
        @klass.find(args)
    end
    
    def destroy(args = {})
        @klass.destroy(args)
    end
    
    def search(args = {})
        @klass.search(args)
    end

    def save(args = {})
        instance = @klass.new(args)
        instance.save
    end
    
  private
    
    def model_class_from_indirection_name
        Class.new # TODO : FIXME make this the indirection class
    end
end
