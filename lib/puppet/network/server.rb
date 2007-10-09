class Puppet::Network::Server
  attr_reader :server_type

  # which HTTP server subclass actually handles web requests of a certain type?  (e.g., :rest => RESTServer)
  def self.server_class_by_name(name)
    klass = (name.to_s + 'Server').to_sym
    const_get klass
  end
  
  # we will actually return an instance of the Server subclass which handles the HTTP web server, instead of 
  # an instance of this generic Server class.  A tiny bit of sleight-of-hand is necessary to make this happen.
  def self.new(args = {})
    server_type = Puppet[:servertype] or raise "No servertype configuration found."
    obj = self.server_class_by_name(server_type).allocate
    obj.send :initialize, args.merge(:server_type => server_type)
    obj
  end
  
  def initialize(args = {})
    @routes = {}
    @listening = false
    @server_type = args[:server_type]
    self.register(args[:handlers]) if args[:handlers]
  end

  def register(*indirections)
    raise ArgumentError, "indirection names are required" if indirections.empty?
    indirections.flatten.each { |i| @routes[i.to_sym] = true }
  end
  
  def unregister(*indirections)
    indirections = @routes.keys if indirections.empty?
    indirections.flatten.each do |i|
      raise(ArgumentError, "indirection [%s] is not known" % i) unless @routes[i.to_sym]
      @routes.delete(i.to_sym)
    end
  end

  def listening?
    @listening
  end
  
  def listen
    raise "Cannot listen -- already listening" if listening?
    start_web_server
    @listening = true
  end
  
  def unlisten
    raise "Cannot unlisten -- not currently listening" unless listening?
    stop_web_server
    @listening = false
  end

  private
  
  def start_web_server
    raise NotImplementedError, "this method needs to be implemented by the actual web server (sub)class"
  end
  
  def stop_web_server
    raise NotImplementedError, "this method needs to be implemented by the actual web server (sub)class"
  end
end


