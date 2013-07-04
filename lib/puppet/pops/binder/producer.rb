# This module contains the Puppet Bindings/Injector subsystem.
# Given a set of layered and precedented bindings, and injector is used to lookup values given a key
# consisting of a type/name combination.
#
# TODO: This piece of documentation is in an odd place (in producer.rb) and should be moved.
#
# @api public
#
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
  # @api public
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

    # Returns the producer (self) after possibly having recreated an internal/wrapped producer.
    # This implementation returns `self`. A derived class may want to override this method
    # to perform initialization/refresh of its internal state. This method is called when
    # a producer is requested.
    # @see Puppet::Pops::Binder::ProducerProducer for an example of implementation.
    #
    def producer(scope)
      self
    end
  end

  # Represents a simple producer that produces its value without any arguments
  # (The default implicit production rule).
  # @api public
  #
  class LambdaProducer < Producer
    # Creates a LambdaProducer based on a lambda taking one argument `scope`.
    #
    # @api public
    def initialize(producer)
      raise ArgumentError, "Argument must be a proc" unless producer.is_a?(Proc)
      @producer = producer
    end

    # Produces the value by calling the lambda given when the producer was created.
    # The extra arguments are ignored.
    # @api public
    #
    def produce(scope, *args)
      @producer.call(scope)
    end

  end

  # A ProducerProducer creates a producer via another producer, and then uses this created producer
  # to produce values. This is useful for custom production of series of values.
  # On each request for a producer, this producer will reset its internal producer (i.e. restarting
  # the series).
  #
  # @param producer_producer [#produce(scope)] the producer of the producer
  #
  # @api public
  #
  class ProducerProducer < Producer
    # Creates  new ProducerProducer given a producer.
    #
    # @param producer_producer [#produce(scope)] the producer of the producer
    #
    # @api public
    #
    def initialize(producer_producer)
      raise ArgumentError, "Argument must be a Producer" unless producer_producer.is_a?(Producer)
      @producer_producer = producer_producer
      @value_producer = nil
    end

    # Produces a value after having created an instance of the wrapped producer (if not already created).
    # @api public
    #
    def produce(scope, *args)
      producer() unless @value_producer
      @value_producer.produce(scope)
    end

    # Updates the internal state to use a new instance of the wrapped producer.
    # @api public
    #
    def producer(scope)
      @value_producer = @producer_producer.produce(scope)
      self
    end
  end
end