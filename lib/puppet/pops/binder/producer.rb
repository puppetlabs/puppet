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

    def producer(scope)
      self
    end
  end

  class ProducerProducer < Producer
    def initialize(producer_producer)
      raise ArgumentError, "Argument must be a Producer" unless producer_producer.is_a?(Producer)
      @producer_producer = producer_producer
      @value_producer = nil
    end

    def produce(scope, *args)
      producer() unless @value_producer
      @value_producer.produce(scope)
    end

    def producer(scope)
      @value_producer = @producer_producer.produce(scope)
      self
    end
  end
end