require 'mocha/infinite_range'
require 'mocha/pretty_parameters'
require 'mocha/expectation_error'

class Object

  alias_method :__is_a__, :is_a?

end

module Mocha
  # Methods on expectations returned from Mocha::MockMethods#expects and Mocha::MockMethods#stubs
  class Expectation
  
    # :stopdoc:
    
    class InvalidExpectation < Exception; end
    
    class AlwaysEqual
      def ==(other)
        true
      end
    end
  
    attr_reader :method_name, :backtrace

    def initialize(mock, method_name, backtrace = nil)
      @mock, @method_name = mock, method_name
      @count = 1
      @parameters, @parameter_block = AlwaysEqual.new, nil
      @invoked, @return_value = 0, nil
      @backtrace = backtrace || caller
      @yield = nil
    end
    
    def yield?
      @yield
    end

    def match?(method_name, *arguments)
      if @parameter_block then
        @parameter_block.call(*arguments)
      else
        (@method_name == method_name) and (@parameters == arguments)
      end
    end

    # :startdoc:
    
    # :call-seq: times(range) -> expectation
    #
    # Modifies expectation so that the number of calls to the expected method must be within a specific +range+.
    #
    # +range+ can be specified as an exact integer or as a range of integers
    #   object = mock()
    #   object.expects(:expected_method).times(3)
    #   3.times { object.expected_method } # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).times(3)
    #   2.times { object.expected_method } # => verify fails
    #
    #   object = mock()
    #   object.expects(:expected_method).times(2..4)
    #   3.times { object.expected_method } # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).times(2..4)
    #   object.expected_method # => verify fails
    def times(range)
      @count = range
      self
    end
  
    # :call-seq: never -> expectation
    #
    # Modifies expectation so that the expected method must never be called.
    #   object = mock()
    #   object.expects(:expected_method).never
    #   object.expected_method # => verify fails
    #
    #   object = mock()
    #   object.expects(:expected_method).never
    #   object.expected_method # => verify succeeds
    def never
      times(0)
      self
    end
  
    # :call-seq: at_least(minimum_number_of_times) -> expectation
    #
    # Modifies expectation so that the expected method must be called at least a +minimum_number_of_times+.
    #   object = mock()
    #   object.expects(:expected_method).at_least(2)
    #   3.times { object.expected_method } # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).at_least(2)
    #   object.expected_method # => verify fails
    def at_least(minimum_number_of_times)
      times(Range.at_least(minimum_number_of_times))
      self
    end
  
    # :call-seq: at_least_once() -> expectation
    #
    # Modifies expectation so that the expected method must be called at least once.
    #   object = mock()
    #   object.expects(:expected_method).at_least_once
    #   object.expected_method # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).at_least_once
    #   # => verify fails
    def at_least_once()
      at_least(1)
      self
    end
  
    # :call-seq: at_most(maximum_number_of_times) -> expectation
    #
    # Modifies expectation so that the expected method must be called at most a +maximum_number_of_times+.
    #   object = mock()
    #   object.expects(:expected_method).at_most(2)
    #   2.times { object.expected_method } # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).at_most(2)
    #   3.times { object.expected_method } # => verify fails
    def at_most(maximum_number_of_times)
      times(Range.at_most(maximum_number_of_times))
      self
    end
  
    # :call-seq: at_most_once() -> expectation
    #
    # Modifies expectation so that the expected method must be called at most once.
    #   object = mock()
    #   object.expects(:expected_method).at_most_once
    #   object.expected_method # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).at_most_once
    #   2.times { object.expected_method } # => verify fails
    def at_most_once()
      at_most(1)
      self
    end
  
    # :call-seq: with(*arguments, &parameter_block) -> expectation
    #
    # Modifies expectation so that the expected method must be called with specified +arguments+.
    #   object = mock()
    #   object.expects(:expected_method).with(:param1, :param2)
    #   object.expected_method(:param1, :param2) # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).with(:param1, :param2)
    #   object.expected_method(:param3) # => verify fails
    # If a +parameter_block+ is given, the block is called with the parameters passed to the expected method.
    # The expectation is matched if the block evaluates to +true+.
    #   object = mock()
    #   object.expects(:expected_method).with() { |value| value % 4 == 0 }
    #   object.expected_method(16) # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).with() { |value| value % 4 == 0 }
    #   object.expected_method(17) # => verify fails
    def with(*arguments, &parameter_block)
      @parameters, @parameter_block = arguments, parameter_block
      class << @parameters; def to_s; join(', '); end; end
      self
    end
  
    # :call-seq: yields(*parameters) -> expectation
    #
    # Modifies expectation so that when the expected method is called, it yields with the specified +parameters+.
    #   object = mock()
    #   object.expects(:expected_method).yields('result')
    #   yielded_value = nil
    #   object.expected_method { |value| yielded_value = value }
    #   yielded_value # => 'result'
    def yields(*parameters)
      @yield = true
      @parameters_to_yield = parameters
      self
    end

    # :call-seq: returns(value) -> expectation
    # :call-seq: returns(*values) -> expectation
    #
    # Modifies expectation so that when the expected method is called, it returns the specified +value+.
    #   object = mock()
    #   object.stubs(:stubbed_method).returns('result')
    #   object.stubbed_method # => 'result'
    #   object.stubbed_method # => 'result'
    # If multiple +values+ are given, these are returned in turn on consecutive calls to the method.
    #   object = mock()
    #   object.stubs(:stubbed_method).returns(1, 2)
    #   object.stubbed_method # => 1
    #   object.stubbed_method # => 2
    # If +value+ is a Proc, then expected method will return result of calling Proc.
    #   object = mock()
    #   object.stubs(:stubbed_method).returns(lambda { rand(100) })
    #   object.stubbed_method # => 41
    #   object.stubbed_method # => 77
    def returns(*values)
      @return_value = (values.size > 1) ? lambda { values.shift } : @return_value = values.first
      self
    end
  
    # :call-seq: raises(exception = RuntimeError, message = nil) -> expectation
    #
    # Modifies expectation so that when the expected method is called, it raises the specified +exception+ with the specified +message+.
    #   object = mock()
    #   object.expects(:expected_method).raises(Exception, 'message')
    #   object.expected_method # => raises exception of class Exception and with message 'message'
    def raises(exception = RuntimeError, message = nil)
      @return_value = message ? lambda { raise exception, message } : lambda { raise exception }
      self
    end

    # :stopdoc:
    
    def invoke
      @invoked += 1
      yield(*@parameters_to_yield) if yield? and block_given?
      @return_value.__is_a__(Proc) ? @return_value.call : @return_value
    end

    def verify
      yield(self) if block_given?
      unless (@count === @invoked) then
        error = ExpectationError.new(error_message(@count, @invoked))
        error.set_backtrace(filtered_backtrace)
        raise error
      end
    end
    
    def mocha_lib_directory
      File.expand_path(File.join(File.dirname(__FILE__), "..")) + File::SEPARATOR
    end
    
    def filtered_backtrace
      backtrace.reject { |location| Regexp.new(mocha_lib_directory).match(File.expand_path(location)) }
    end
  
    def method_signature
      return "#{method_name}" if @parameters.__is_a__(AlwaysEqual)
      "#{@method_name}(#{PrettyParameters.new(@parameters).pretty})"
    end
    
    def error_message(expected_count, actual_count)
      "#{@mock.mocha_inspect}.#{method_signature} - expected calls: #{expected_count}, actual calls: #{actual_count}"
    end
  
    # :startdoc:
    
  end

  # :stopdoc:
  
  class Stub < Expectation
  
    def verify
      true
    end
  
  end

  class MissingExpectation < Expectation
  
    def initialize(mock, method_name)
      super
      @invoked = true
    end
  
    def verify
      msg = error_message(0, 1)
      similar_expectations_list = similar_expectations.collect { |expectation| expectation.method_signature }.join("\n")
      msg << "\nSimilar expectations:\n#{similar_expectations_list}" unless similar_expectations.empty?
      error = ExpectationError.new(msg)
      error.set_backtrace(filtered_backtrace)
      raise error if @invoked
    end
  
    def similar_expectations
      @mock.expectations.select { |expectation| expectation.method_name == self.method_name }
    end
  
  end

  # :startdoc:
  
end