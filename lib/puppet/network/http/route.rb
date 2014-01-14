class Puppet::Network::HTTP::Route
  MethodNotAllowedHandler = lambda do |req, res|
    raise Puppet::Network::HTTP::Error::HTTPMethodNotAllowedError, "method #{req.method} not allowed for route #{req.path}"
  end

  attr_reader :path_matcher

  def self.path(path_matcher)
    new(path_matcher)
  end

  def initialize(path_matcher)
    @path_matcher = path_matcher
    @method_handlers = {
      :GET => [MethodNotAllowedHandler],
      :HEAD => [MethodNotAllowedHandler],
      :OPTIONS => [MethodNotAllowedHandler],
      :POST => [MethodNotAllowedHandler],
      :PUT => [MethodNotAllowedHandler]
    }
    @chained = []
  end

  def get(*handlers)
    @method_handlers[:GET] = handlers
    return self
  end

  def head(*handlers)
    @method_handlers[:HEAD] = handlers
    return self
  end

  def options(*handlers)
    @method_handlers[:OPTIONS] = handlers
    return self
  end

  def post(*handlers)
    @method_handlers[:POST] = handlers
    return self
  end

  def put(*handlers)
    @method_handlers[:PUT] = handlers
    return self
  end

  def any(*handlers)
    @method_handlers.each do |method, registered_handlers|
      @method_handlers[method] = handlers
    end
    return self
  end

  def chain(*routes)
    @chained = routes
    self
  end

  def matches?(request)
    Puppet.debug("Evaluating match for #{self.inspect}")
    if match(request.routing_path)
      return true
    else
      Puppet.debug("Did not match path (#{request.routing_path.inspect})")
    end
    return false
  end

  def process(request, response)
    @method_handlers[request.method.upcase.intern].each do |handler|
      handler.call(request, response)
    end

    subrequest = request.route_into(match(request.routing_path).to_s)
    if chained_route = @chained.find { |route| route.matches?(subrequest) }
      chained_route.process(subrequest, response)
    end
  end

  def inspect
    "Route #{@path_matcher.inspect}"
  end

  private

  def match(path)
    @path_matcher.match(path)
  end
end
