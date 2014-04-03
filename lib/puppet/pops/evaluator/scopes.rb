class Puppet::Pops::Evaluator::Scopes
  attr_reader :global

  def initialize
    @global = GlobalScope.new
  end

  def bind_global(name, value)
    @global.bind(name, value)
  end

  class GlobalScope
    def initialize
      @bindings = {}
    end

    def bind(name, value)
      @bindings[name] = value
    end

    def lookup(name)
      @bindings[name]
    end
  end
end
