module Spec
  module Runner
    class Reporter
      
      def initialize(formatters, backtrace_tweaker)
        @formatters = formatters
        @backtrace_tweaker = backtrace_tweaker
        clear!
      end
      
      def add_behaviour(name)
        @formatters.each{|f| f.add_behaviour(name)}
        @behaviour_names << name
      end
      
      def example_started(name)
        @formatters.each{|f| f.example_started(name)}
      end
      
      def example_finished(name, error=nil, failure_location=nil, not_implemented = false)
        @example_names << name
        
        if not_implemented
          example_pending(@behaviour_names.last, name)
        elsif error.nil?
          example_passed(name)
        elsif Spec::DSL::ExamplePendingError === error
          example_pending(@behaviour_names.last, name, error.message)
        else
          example_failed(name, error, failure_location)
        end
      end

      def start(number_of_examples)
        clear!
        @start_time = Time.new
        @formatters.each{|f| f.start(number_of_examples)}
      end
  
      def end
        @end_time = Time.new
      end
  
      # Dumps the summary and returns the total number of failures
      def dump
        @formatters.each{|f| f.start_dump}
        dump_failures
        @formatters.each do |f| 
          f.dump_summary(duration, @example_names.length, @failures.length, @pending_count)
          f.close
        end
        @failures.length
      end

    private
  
      def clear!
        @behaviour_names = []
        @failures = []
        @pending_count = 0
        @example_names = []
        @start_time = nil
        @end_time = nil
      end
  
      def dump_failures
        return if @failures.empty?
        @failures.inject(1) do |index, failure|
          @formatters.each{|f| f.dump_failure(index, failure)}
          index + 1
        end
      end

      def duration
        return @end_time - @start_time unless (@end_time.nil? or @start_time.nil?)
        return "0.0"
      end
      
      def example_passed(name)
        @formatters.each{|f| f.example_passed(name)}
      end

      def example_failed(name, error, failure_location)
        @backtrace_tweaker.tweak_backtrace(error, failure_location)
        example_name = "#{@behaviour_names.last} #{name}"
        failure = Failure.new(example_name, error)
        @failures << failure
        @formatters.each{|f| f.example_failed(name, @failures.length, failure)}
      end
      
      def example_pending(behaviour_name, example_name, message="Not Yet Implemented")
        @pending_count += 1
        @formatters.each{|f| f.example_pending(behaviour_name, example_name, message)}
      end
      
      class Failure
        attr_reader :exception
        
        def initialize(example_name, exception)
          @example_name = example_name
          @exception = exception
        end

        def header
          if expectation_not_met?
            "'#{@example_name}' FAILED"
          elsif pending_fixed?
            "'#{@example_name}' FIXED"
          else
            "#{@exception.class.name} in '#{@example_name}'"
          end
        end
        
        def pending_fixed?
          @exception.is_a?(Spec::DSL::PendingFixedError)
        end

        def expectation_not_met?
          @exception.is_a?(Spec::Expectations::ExpectationNotMetError)
        end

      end
    end
  end
end
