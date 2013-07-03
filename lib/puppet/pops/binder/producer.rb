module Puppet::Pops::Binder
  # Producer is an abstract base class representing the base contract for a bound producer.
  # This class is used internally when an explicit producer is wanted (i.e. when looking up
  # a producer instead of an instance).
  #
  # Custom Producers
  # ----------------
  # The intent is also that this class is derived for custom producers that require additional
  # arguments when producing an instance. Such a custom producer may raise an error if called
  # with too few arguments, or may implement specific produce methods and always raise an
  # error on #produce indicating that this producer requires custom calls and that it can not
  # be used as an implicit producer.
  #
  # @abstract
  #
  class Producer
    # Produces an instance.
    # @param scope [Puppet::Parser:Scope] the scope to use for evaluation
    # @param *args [Object] arguments to custom producers, always empty for implicit productions
    # @return [Object] the produced instance (should never be nil).
    #
    def produce(scope, *args)
      raise NotImplementedError, "Derived class should implement #produce(scope)"
    end
  end

  # Represents a simple producer that produces its value without ny arguments
  # (The default implicit production rule).
  #
  class LambdaProducer < Producer
    def initialize(producer)
      raise ArgumentError, "Argument must be a proc" unless producer.is_a?(Proc)
      @producer = producer
    end

    def produce(scope, *args)
      @producer.call(scope)
    end
  end

  # A wrapping/delegating producer that delegates to another producer
  # for the production of a value.
  class WrappingProducer < Producer
    def initialize(producer)
      raise ArgumentError, "Argument must be a Producer" unless producer.is_a?(Producer)
      @producer = producer
    end

    def produce(scope)
      @producer.produce(scope)
    end
  end
end