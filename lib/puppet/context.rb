module Puppet::Context
  class ValueAlreadyBoundError < Puppet::Error; end
  class UndefinedBindingError < Puppet::Error; end

  class Bindings
    attr_reader :parent

    def initialize(parent)
      @parent = parent
      @table = {}
    end

    def bind(name, value)
      if @table.include?(name)
        raise ValueAlreadyBoundError, name
      else
        @table[name] = value
      end
    end

    def lookup(name, block)
      if @table.include?(name)
        @table[name]
      elsif @parent
        @parent.lookup(name, block)
      elsif block
        block.call
      else
        raise UndefinedBindingError, name
      end
    end
  end

  @bindings = Bindings.new(nil)

  def self.push
    @bindings = Bindings.new(@bindings)
  end

  def self.pop
    @bindings = @bindings.parent
  end

  def self.bind(name, value)
    @bindings.bind(name, value)
  end

  def self.lookup(name, &block)
    @bindings.lookup(name, block)
  end

  def self.override(bindings)
    push
    bindings.each do |name, value|
      bind(name, value)
    end

    yield
  ensure
    pop
  end
end
