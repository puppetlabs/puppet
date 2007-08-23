require 'timeout'

module Spec
  module DSL
    class Example
      # The global sequence number of this example
      attr_accessor :number
      
      def initialize(description, options={}, &example_block)
        @from = caller(0)[3]
        @options = options
        @example_block = example_block
        @description = description
        @description_generated_proc = lambda { |desc| @generated_description = desc }
      end
      
      def run(reporter, before_each_block, after_each_block, dry_run, execution_context, timeout=nil)
        @dry_run = dry_run
        reporter.example_started(self)
        return reporter.example_finished(self) if dry_run

        errors = []
        location = nil
        Timeout.timeout(timeout) do
          before_each_ok = before_example(execution_context, errors, &before_each_block)
          example_ok = run_example(execution_context, errors) if before_each_ok
          after_each_ok = after_example(execution_context, errors, &after_each_block)
          location = failure_location(before_each_ok, example_ok, after_each_ok)
        end

        ExampleShouldRaiseHandler.new(@from, @options).handle(errors)
        reporter.example_finished(self, errors.first, location, @example_block.nil?) if reporter
      end
      
      def matches?(matcher, specified_examples)
        matcher.example_desc = description
        matcher.matches?(specified_examples)
      end
      
      def description
        @description == :__generate_description ? generated_description : @description
      end
      
      def to_s
        description
      end

    private
      
      def generated_description
        return @generated_description if @generated_description
        if @dry_run
          "NO NAME (Because of --dry-run)"
        else
          if @failed
            "NO NAME (Because of Error raised in matcher)"
          else
            "NO NAME (Because there were no expectations)"
          end
        end
      end
      
      def before_example(execution_context, errors, &behaviour_before_block)
        setup_mocks(execution_context)
        Spec::Matchers.description_generated(@description_generated_proc)
        
        builder = CompositeProcBuilder.new
        before_proc = builder.proc(&append_errors(errors))
        execution_context.instance_eval(&before_proc)
        
        execution_context.instance_eval(&behaviour_before_block) if behaviour_before_block
        return errors.empty?
      rescue Exception => e
        @failed = true
        errors << e
        return false
      end

      def run_example(execution_context, errors)
        begin
          execution_context.instance_eval(&@example_block) if @example_block
          return true
        rescue Exception => e
          @failed = true
          errors << e
          return false
        end
      end

      def after_example(execution_context, errors, &behaviour_after_each)
        execution_context.instance_eval(&behaviour_after_each) if behaviour_after_each

        begin
          verify_mocks(execution_context)
        ensure
          teardown_mocks(execution_context)
        end

        Spec::Matchers.unregister_description_generated(@description_generated_proc)

        builder = CompositeProcBuilder.new
        after_proc = builder.proc(&append_errors(errors))
        execution_context.instance_eval(&after_proc)

        return errors.empty?
      rescue Exception => e
        @failed = true
        errors << e
        return false
      end
      
      def setup_mocks(execution_context)
        execution_context.setup_mocks_for_rspec if execution_context.respond_to?(:setup_mocks_for_rspec)
      end
      
      def verify_mocks(execution_context)
        execution_context.verify_mocks_for_rspec if execution_context.respond_to?(:verify_mocks_for_rspec)
      end
      
      def teardown_mocks(execution_context)
        execution_context.teardown_mocks_for_rspec if execution_context.respond_to?(:teardown_mocks_for_rspec)
      end
      
      def append_errors(errors)
        proc {|error| errors << error}
      end
      
      def failure_location(before_each_ok, example_ok, after_each_ok)
        return 'before(:each)' unless before_each_ok
        return description unless example_ok
        return 'after(:each)' unless after_each_ok
      end
    end
  end
end
