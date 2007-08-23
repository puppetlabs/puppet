module Spec
  module DSL
    # See http://rspec.rubyforge.org/documentation/before_and_after.html
    module BehaviourCallbacks
      def prepend_before(*args, &block)
        scope, options = scope_and_options(*args)
        add(scope, options, :before, :unshift, &block)
      end
      def append_before(*args, &block)
        scope, options = scope_and_options(*args)
        add(scope, options, :before, :<<, &block)
      end
      alias_method :before, :append_before

      def prepend_after(*args, &block)
        scope, options = scope_and_options(*args)
        add(scope, options, :after, :unshift, &block)
      end
      alias_method :after, :prepend_after
      def append_after(*args, &block)
        scope, options = scope_and_options(*args)
        add(scope, options, :after, :<<, &block)
      end
      
      def scope_and_options(*args)
        args, options = args_and_options(*args)
        scope = (args[0] || :each), options
      end
      
      def add(scope, options, where, how, &block)
        scope ||= :each
        options ||= {}
        behaviour_type = options[:behaviour_type]
        case scope
          when :each; self.__send__("#{where}_each_parts", behaviour_type).__send__(how, block)
          when :all;  self.__send__("#{where}_all_parts", behaviour_type).__send__(how, block)
        end
      end
      
      def remove_after(scope, &block)
        after_each_parts.delete(block)
      end

      # Deprecated. Use before(:each)
      def setup(&block)
        before(:each, &block)
      end

      # Deprecated. Use after(:each)
      def teardown(&block)
        after(:each, &block)
      end

      def before_all_parts(behaviour_type=nil) # :nodoc:
        @before_all_parts ||= {}
        @before_all_parts[behaviour_type] ||= []
      end

      def after_all_parts(behaviour_type=nil) # :nodoc:
        @after_all_parts ||= {}
        @after_all_parts[behaviour_type] ||= []
      end

      def before_each_parts(behaviour_type=nil) # :nodoc:
        @before_each_parts ||= {}
        @before_each_parts[behaviour_type] ||= []
      end

      def after_each_parts(behaviour_type=nil) # :nodoc:
        @after_each_parts ||= {}
        @after_each_parts[behaviour_type] ||= []
      end

      def clear_before_and_after! # :nodoc:
        @before_all_parts = nil
        @after_all_parts = nil
        @before_each_parts = nil
        @after_each_parts = nil
      end
    end
  end
end
