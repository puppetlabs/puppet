require 'mocha/infinite_range'
require 'mocha/pretty_parameters'
require 'mocha/expectation_error'
require 'mocha/return_values'
require 'mocha/exception_raiser'
require 'mocha/yield_parameters'
require 'mocha/is_a'

module Mocha # :nodoc:
  
  # Methods on expectations returned from Mock#expects, Mock#stubs, Object#expects and Object#stubs.
  class Expectation
  
    # :stopdoc:
    
    class AlwaysEqual
      def ==(other)
        true
      end
    end
  
    attr_reader :method_name, :backtrace

    def initialize(mock, method_name, backtrace = nil)
      @mock, @method_name = mock, method_name
      @expected_count = 1
      @parameters, @parameter_block = AlwaysEqual.new, nil
      @invoked_count, @return_values = 0, ReturnValues.new
      @backtrace = backtrace || caller
      @yield_parameters = YieldParameters.new
    end
    
    def match?(method_name, *arguments)
      return false unless @method_name == method_name
      if @parameter_block then
        return false unless @parameter_block.call(*arguments)
      else
        return false unless (@parameters == arguments)
      end
      if @expected_count.is_a?(Range) then
        return false unless @invoked_count < @expected_count.last
      else
        return false unless @invoked_count < @expected_count
      end
      return true
    end

    # :startdoc:
    
    # :call-seq: times(range) -> expectation
    #
    # Modifies expectation so that the number of calls to the expected method must be within a specific +range+.
    #
    # +range+ can be specified as an exact integer or as a range of integers
    #   object = mock()
    #   object.expects(:expected_method).times(3)
    #   3.times { object.expected_method }
    #   # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).times(3)
    #   2.times { object.expected_method }
    #   # => verify fails
    #
    #   object = mock()
    #   object.expects(:expected_method).times(2..4)
    #   3.times { object.expected_method }
    #   # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).times(2..4)
    #   object.expected_method
    #   # => verify fails
    def times(range)
      @expected_count = range
      self
    end
  
    # :call-seq: once() -> expectation
    #
    # Modifies expectation so that the expected method must be called exactly once.
    # Note that this is the default behaviour for an expectation, but you may wish to use it for clarity/emphasis.
    #   object = mock()
    #   object.expects(:expected_method).once
    #   object.expected_method
    #   # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).once
    #   object.expected_method
    #   object.expected_method
    #   # => verify fails
    #
    #   object = mock()
    #   object.expects(:expected_method).once
    #   # => verify fails
    def once()
      times(1)
      self
    end
  
    # :call-seq: never() -> expectation
    #
    # Modifies expectation so that the expected method must never be called.
    #   object = mock()
    #   object.expects(:expected_method).never
    #   object.expected_method
    #   # => verify fails
    #
    #   object = mock()
    #   object.expects(:expected_method).never
    #   object.expected_method
    #   # => verify succeeds
    def never
      times(0)
      self
    end
  
    # :call-seq: at_least(minimum_number_of_times) -> expectation
    #
    # Modifies expectation so that the expected method must be called at least a +minimum_number_of_times+.
    #   object = mock()
    #   object.expects(:expected_method).at_least(2)
    #   3.times { object.expected_method }
    #   # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).at_least(2)
    #   object.expected_method
    #   # => verify fails
    def at_least(minimum_number_of_times)
      times(Range.at_least(minimum_number_of_times))
      self
    end
  
    # :call-seq: at_least_once() -> expectation
    #
    # Modifies expectation so that the expected method must be called at least once.
    #   object = mock()
    #   object.expects(:expected_method).at_least_once
    #   object.expected_method
    #   # => verify succeeds
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
    #   2.times { object.expected_method }
    #   # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).at_most(2)
    #   3.times { object.expected_method }
    #   # => verify fails
    def at_most(maximum_number_of_times)
      times(Range.at_most(maximum_number_of_times))
      self
    end
  
    # :call-seq: at_most_once() -> expectation
    #
    # Modifies expectation so that the expected method must be called at most once.
    #   object = mock()
    #   object.expects(:expected_method).at_most_once
    #   object.expected_method
    #   # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).at_most_once
    #   2.times { object.expected_method }
    #   # => verify fails
    def at_most_once()
      at_most(1)
      self
    end
  
    # :call-seq: with(*arguments, &parameter_block) -> expectation
    #
    # Modifies expectation so that the expected method must be called with specified +arguments+.
    #   object = mock()
    #   object.expects(:expected_method).with(:param1, :param2)
    #   object.expected_method(:param1, :param2)
    #   # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).with(:param1, :param2)
    #   object.expected_method(:param3)
    #   # => verify fails
    # May be used with parameter matchers in Mocha::ParameterMatchers.
    #
    # If a +parameter_block+ is given, the block is called with the parameters passed to the expected method.
    # The expectation is matched if the block evaluates to +true+.
    #   object = mock()
    #   object.expects(:expected_method).with() { |value| value % 4 == 0 }
    #   object.expected_method(16)
    #   # => verify succeeds
    #
    #   object = mock()
    #   object.expects(:expected_method).with() { |value| value % 4 == 0 }
    #   object.expected_method(17)
    #   # => verify fails
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
    # May be called multiple times on the same expectation for consecutive invocations. Also see Expectation#then.
    #   object = mock()
    #   object.stubs(:expected_method).yields(1).then.yields(2)
    #   yielded_values_from_first_invocation = []
    #   yielded_values_from_second_invocation = []
    #   object.expected_method { |value| yielded_values_from_first_invocation << value } # first invocation
    #   object.expected_method { |value| yielded_values_from_second_invocation << value } # second invocation
    #   yielded_values_from_first_invocation # => [1]
    #   yielded_values_from_second_invocation # => [2]
    def yields(*parameters)
      @yield_parameters.add(*parameters)
      self
    end
    
    # :call-seq: multiple_yields(*parameter_groups) -> expectation
    #
    # Modifies expectation so that when the expected method is called, it yields multiple times per invocation with the specified +parameter_groups+.
    #   object = mock()
    #   object.expects(:expected_method).multiple_yields(['result_1', 'result_2'], ['result_3'])
    #   yielded_values = []
    #   object.expected_method { |*values| yielded_values << values }
    #   yielded_values # => [['result_1', 'result_2'], ['result_3]]
    # May be called multiple times on the same expectation for consecutive invocations. Also see Expectation#then.
    #   object = mock()
    #   object.stubs(:expected_method).multiple_yields([1, 2], [3]).then.multiple_yields([4], [5, 6])
    #   yielded_values_from_first_invocation = []
    #   yielded_values_from_second_invocation = []
    #   object.expected_method { |*values| yielded_values_from_first_invocation << values } # first invocation
    #   object.expected_method { |*values| yielded_values_from_second_invocation << values } # second invocation
    #   yielded_values_from_first_invocation # => [[1, 2], [3]]
    #   yielded_values_from_second_invocation # => [[4], [5, 6]]
    def multiple_yields(*parameter_groups)
      @yield_parameters.multiple_add(*parameter_groups)
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
    # May be called multiple times on the same expectation. Also see Expectation#then.
    #   object = mock()
    #   object.stubs(:expected_method).returns(1, 2).then.returns(3)
    #   object.expected_method # => 1
    #   object.expected_method # => 2
    #   object.expected_method # => 3
    # May be called in conjunction with Expectation#raises on the same expectation.
    #   object = mock()
    #   object.stubs(:expected_method).returns(1, 2).then.raises(Exception)
    #   object.expected_method # => 1
    #   object.expected_method # => 2
    #   object.expected_method # => raises exception of class Exception1
    # If +value+ is a +Proc+, then the expected method will return the result of calling <tt>Proc#call</tt>.
    #
    # This usage is _deprecated_.
    # Use explicit multiple return values and/or multiple expectations instead.
    #
    # A +Proc+ instance will be treated the same as any other value in a future release.
    #   object = mock()
    #   object.stubs(:stubbed_method).returns(lambda { rand(100) })
    #   object.stubbed_method # => 41
    #   object.stubbed_method # => 77
    def returns(*values)
      @return_values += ReturnValues.build(*values)
      self
    end
  
    # :call-seq: raises(exception = RuntimeError, message = nil) -> expectation
    #
    # Modifies expectation so that when the expected method is called, it raises the specified +exception+ with the specified +message+.
    #   object = mock()
    #   object.expects(:expected_method).raises(Exception, 'message')
    #   object.expected_method # => raises exception of class Exception and with message 'message'
    # May be called multiple times on the same expectation. Also see Expectation#then.
    #   object = mock()
    #   object.stubs(:expected_method).raises(Exception1).then.raises(Exception2)
    #   object.expected_method # => raises exception of class Exception1
    #   object.expected_method # => raises exception of class Exception2
    # May be called in conjunction with Expectation#returns on the same expectation.
    #   object = mock()
    #   object.stubs(:expected_method).raises(Exception).then.returns(2, 3)
    #   object.expected_method # => raises exception of class Exception1
    #   object.expected_method # => 2
    #   object.expected_method # => 3
    def raises(exception = RuntimeError, message = nil)
      @return_values += ReturnValues.new(ExceptionRaiser.new(exception, message))
      self
    end

    # :call-seq: then() -> expectation
    #
    # Syntactic sugar to improve readability. Has no effect on state of the expectation.
    #   object = mock()
    #   object.stubs(:expected_method).returns(1, 2).then.raises(Exception).then.returns(4)
    #   object.expected_method # => 1
    #   object.expected_method # => 2
    #   object.expected_method # => raises exception of class Exception
    #   object.expected_method # => 4
    def then
      self
    end
    
    # :stopdoc:
    
    def invoke
      @invoked_count += 1
      if block_given? then
        @yield_parameters.next_invocation.each do |yield_parameters|
          yield(*yield_parameters)
        end
      end
      @return_values.next
    end

    def verify
      yield(self) if block_given?
      unless (@expected_count === @invoked_count) then
        error = ExpectationError.new(error_message(@expected_count, @invoked_count))
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
      "#{@mock.mocha_inspect}.#{method_signature} - expected calls: #{expected_count.mocha_inspect}, actual calls: #{actual_count}"
    end
  
    # :startdoc:
    
  end

end