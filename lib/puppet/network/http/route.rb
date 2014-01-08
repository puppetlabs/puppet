class Puppet::Network::HTTP::Route
  def self.post(path_matcher, *handlers)
    new("POST", lambda { |method| method == "POST" }, path_matcher, *handlers)
  end

  def self.get(path_matcher, *handlers)
    new("GET", lambda { |method| method == "GET" }, path_matcher, *handlers)
  end

  def self.any(path_matcher, *handlers)
    new("ANY", lambda { |method| true }, path_matcher, *handlers)
  end

  def initialize(method_description, method_matcher, path_matcher, *handlers)
    @method_description = method_description
    @method_matcher = method_matcher
    @handlers = handlers
    @path_matcher = path_matcher
  end

  def matches?(request)
    Puppet.debug("Evaluating match for #{self.inspect}")
    if @method_matcher.call(request.method)
      if @path_matcher.match(request.path)
        return true
      else
        Puppet.debug("Matched method (#{request.method.inspect}) but not path (#{request.path.inspect})")
      end
    else
      Puppet.debug("Did not match method (#{request.method.inspect})")
    end
  end

  def process(request, response)
    @handlers.each { |handler| handler.call(request, response) }
  end

  def inspect
    "Route #{@method_description} #{@path_matcher} to <#{@handlers.collect(&:inspect).join(', ')}>"
  end
end
