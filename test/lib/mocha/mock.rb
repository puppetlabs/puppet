require 'mocha/expectation'
require 'mocha/stub'
require 'mocha/missing_expectation'
require 'mocha/metaclass'

module Mocha # :nodoc:

  # Traditional mock object.
  #
  # Methods return an Expectation which can be further modified by methods on Expectation.
  class Mock
    
    # :stopdoc:
    
    def initialize(stub_everything = false, name = nil)
      @stub_everything = stub_everything
      @mock_name = name
      @expectations = []
      @responder = nil
    end

    attr_reader :stub_everything, :expectations
  
    # :startdoc:

    # :call-seq: expects(method_name) -> expectation
    #            expects(method_names) -> last expectation
    #
    # Adds an expectation that a method identified by +method_name+ symbol must be called exactly once with any parameters.
    # Returns the new expectation which can be further modified by methods on Expectation.
    #   object = mock()
    #   object.expects(:method1)
    #   object.method1
    #   # no error raised
    #
    #   object = mock()
    #   object.expects(:method1)
    #   # error raised, because method1 not called exactly once
    # If +method_names+ is a +Hash+, an expectation will be set up for each entry using the key as +method_name+ and value as +return_value+.
    #   object = mock()
    #   object.expects(:method1 => :result1, :method2 => :result2)
    #
    #   # exactly equivalent to
    #
    #   object = mock()
    #   object.expects(:method1).returns(:result1)
    #   object.expects(:method2).returns(:result2)
    #
    # Aliased by <tt>\_\_expects\_\_</tt>
    def expects(method_name_or_hash, backtrace = nil)
      if method_name_or_hash.is_a?(Hash) then
        method_name_or_hash.each do |method_name, return_value|
          add_expectation(Expectation.new(self, method_name, backtrace).returns(return_value))
        end
      else
        add_expectation(Expectation.new(self, method_name_or_hash, backtrace))
      end
    end
    
    # :call-seq: stubs(method_name) -> expectation
    #            stubs(method_names) -> last expectation
    #
    # Adds an expectation that a method identified by +method_name+ symbol may be called any number of times with any parameters.
    # Returns the new expectation which can be further modified by methods on Expectation.
    #   object = mock()
    #   object.stubs(:method1)
    #   object.method1
    #   object.method1
    #   # no error raised
    # If +method_names+ is a +Hash+, an expectation will be set up for each entry using the key as +method_name+ and value as +return_value+.
    #   object = mock()
    #   object.stubs(:method1 => :result1, :method2 => :result2)
    #
    #   # exactly equivalent to
    #
    #   object = mock()
    #   object.stubs(:method1).returns(:result1)
    #   object.stubs(:method2).returns(:result2)
    #
    # Aliased by <tt>\_\_stubs\_\_</tt>
    def stubs(method_name_or_hash, backtrace = nil)
      if method_name_or_hash.is_a?(Hash) then
        method_name_or_hash.each do |method_name, return_value|
          add_expectation(Stub.new(self, method_name, backtrace).returns(return_value))
        end
      else
        add_expectation(Stub.new(self, method_name_or_hash, backtrace))
      end
    end
    
    # :call-seq: responds_like(responder) -> mock
    #
    # Constrains the +mock+ so that it can only expect or stub methods to which +responder+ responds. The constraint is only applied at method invocation time.
    #
    # A +NoMethodError+ will be raised if the +responder+ does not <tt>respond_to?</tt> a method invocation (even if the method has been expected or stubbed).
    #
    # The +mock+ will delegate its <tt>respond_to?</tt> method to the +responder+.
    #   class Sheep
    #     def chew(grass); end
    #     def self.number_of_legs; end
    #   end
    #
    #   sheep = mock('sheep')
    #   sheep.expects(:chew)
    #   sheep.expects(:foo)
    #   sheep.respond_to?(:chew) # => true
    #   sheep.respond_to?(:foo) # => true
    #   sheep.chew
    #   sheep.foo
    #   # no error raised
    #
    #   sheep = mock('sheep')
    #   sheep.responds_like(Sheep.new)
    #   sheep.expects(:chew)
    #   sheep.expects(:foo)
    #   sheep.respond_to?(:chew) # => true
    #   sheep.respond_to?(:foo) # => false
    #   sheep.chew
    #   sheep.foo # => raises NoMethodError exception
    #
    #   sheep_class = mock('sheep_class')
    #   sheep_class.responds_like(Sheep)
    #   sheep_class.stubs(:number_of_legs).returns(4)
    #   sheep_class.expects(:foo)
    #   sheep_class.respond_to?(:number_of_legs) # => true
    #   sheep_class.respond_to?(:foo) # => false
    #   assert_equal 4, sheep_class.number_of_legs
    #   sheep_class.foo # => raises NoMethodError exception
    #
    # Aliased by +quacks_like+
    def responds_like(object)
      @responder = object
      self
    end
    
    # :stopdoc:

    alias_method :__expects__, :expects

    alias_method :__stubs__, :stubs
    
    alias_method :quacks_like, :responds_like

    def add_expectation(expectation)
      @expectations << expectation
      method_name = expectation.method_name
      self.__metaclass__.send(:undef_method, method_name) if self.__metaclass__.method_defined?(method_name)
      expectation
    end

    def method_missing(symbol, *arguments, &block)
      if @responder and not @responder.respond_to?(symbol)
        raise NoMethodError, "undefined method `#{symbol}' for #{self.mocha_inspect} which responds like #{@responder.mocha_inspect}"
      end
      matching_expectation = matching_expectation(symbol, *arguments)
      if matching_expectation then
        matching_expectation.invoke(&block)
      elsif stub_everything then
        return
      else
        begin
          super_method_missing(symbol, *arguments, &block)
    		rescue NoMethodError
    			unexpected_method_called(symbol, *arguments)
    		end
  		end
  	end
  	
  	def respond_to?(symbol)
	    if @responder then
	      @responder.respond_to?(symbol)
      else
    	  @expectations.any? { |expectation| expectation.method_name == symbol }
  	  end
	  end
	
  	def super_method_missing(symbol, *arguments, &block)
  	  raise NoMethodError
    end

  	def unexpected_method_called(symbol, *arguments)
      MissingExpectation.new(self, symbol).with(*arguments).verify
    end
	
  	def matching_expectation(symbol, *arguments)
      @expectations.reverse.detect { |expectation| expectation.match?(symbol, *arguments) }
    end
  
    def verify(&block)
      @expectations.each { |expectation| expectation.verify(&block) }
    end
  
    def mocha_inspect
      address = self.__id__ * 2
      address += 0x100000000 if address < 0
      @mock_name ? "#<Mock:#{@mock_name}>" : "#<Mock:0x#{'%x' % address}>"
    end
    
    def inspect
      mocha_inspect
    end

    # :startdoc:

  end

end