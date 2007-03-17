module Spec
  module Runner
    class Specification

      class << self
        attr_accessor :current, :generated_description
        protected :current=

        callback_events :before_setup, :after_teardown
      end

      attr_reader :spec_block
      callback_events :before_setup, :after_teardown

      def initialize(name, opts={}, &spec_block)
        @from = caller(0)[3]
        @description = name
        @options = opts
        @spec_block = spec_block
        @description_generated_callback = lambda { |desc| @generated_description = desc }
      end

      def run(reporter, setup_block, teardown_block, dry_run, execution_context)
        reporter.spec_started(name) if reporter
        return reporter.spec_finished(name) if dry_run

        errors = []
        begin
          set_current
          setup_ok = setup_spec(execution_context, errors, &setup_block)
          spec_ok = execute_spec(execution_context, errors) if setup_ok
          teardown_ok = teardown_spec(execution_context, errors, &teardown_block)
        ensure
          clear_current
        end

        SpecShouldRaiseHandler.new(@from, @options).handle(errors)
        reporter.spec_finished(name, errors.first, failure_location(setup_ok, spec_ok, teardown_ok)) if reporter
      end
      
      def matches?(matcher, description)
        matcher.spec_desc = name
        matcher.matches?(description)
      end
      
      private
      def name
        @description == :__generate_description ? generated_description : @description
      end
      
      def generated_description
        @generated_description || "NAME NOT GENERATED"
      end
      
      def setup_spec(execution_context, errors, &setup_block)
        notify_before_setup(errors)
        execution_context.instance_eval(&setup_block) if setup_block
        return errors.empty?
      rescue => e
        errors << e
        return false
      end

      def execute_spec(execution_context, errors)
        begin
          execution_context.instance_eval(&spec_block)
          return true
        rescue Exception => e
          errors << e
          return false
        end
      end

      def teardown_spec(execution_context, errors, &teardown_block)
        execution_context.instance_eval(&teardown_block) if teardown_block
        notify_after_teardown(errors)
        return errors.empty?
      rescue => e
        errors << e
        return false
      end

      def notify_before_setup(errors)
        notify_class_callbacks(:before_setup, self, &append_errors(errors))
        notify_callbacks(:before_setup, self, &append_errors(errors))
      end
      
      def notify_after_teardown(errors)
        notify_callbacks(:after_teardown, self, &append_errors(errors))
        notify_class_callbacks(:after_teardown, self, &append_errors(errors))
      end
      
      def append_errors(errors)
        proc {|error| errors << error}
      end
      
      def set_current
        Spec::Matchers.description_generated(&@description_generated_callback)
        self.class.send(:current=, self)
      end

      def clear_current
        Spec::Matchers.unregister_callback(:description_generated, @description_generated_callback)
        self.class.send(:current=, nil)
      end

      def failure_location(setup_ok, spec_ok, teardown_ok)
        return 'setup' unless setup_ok
        return name unless spec_ok
        return 'teardown' unless teardown_ok
      end
    end
  end
end
