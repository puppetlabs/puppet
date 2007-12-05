module Spec
  module DSL
    module BehaviourEval
      module ModuleMethods
        include BehaviourCallbacks

        attr_writer :behaviour
        attr_accessor :description

        # RSpec runs every example in a new instance of Object, mixing in
        # the behaviour necessary to run examples. Because this behaviour gets
        # mixed in, it can get mixed in to an instance of any class at all.
        #
        # This is something that you would hardly ever use, but there is one
        # common use case for it - inheriting from Test::Unit::TestCase. RSpec's
        # Rails plugin uses this feature to provide access to all of the features
        # that are available for Test::Unit within RSpec examples.
        def inherit(klass)
          raise ArgumentError.new("Shared behaviours cannot inherit from classes") if @behaviour.shared?
          @behaviour_superclass = klass
          derive_execution_context_class_from_behaviour_superclass
        end

        # You can pass this one or many modules. Each module will subsequently
        # be included in the each object in which an example is run. Use this
        # to provide global helper methods to your examples.
        #
        # == Example
        #
        #   module HelperMethods
        #     def helper_method
        #       ...
        #     end
        #   end
        #
        #   describe Thing do
        #     include HelperMethods
        #     it "should do stuff" do
        #       helper_method
        #     end
        #   end
        def include(*mods)
          mods.each do |mod|
            included_modules << mod
            mod.send :included, self
          end
        end

        # Use this to pull in examples from shared behaviours.
        # See Spec::Runner for information about shared behaviours.
        def it_should_behave_like(behaviour_description)
          behaviour = @behaviour.class.find_shared_behaviour(behaviour_description)
          if behaviour.nil?
            raise RuntimeError.new("Shared Behaviour '#{behaviour_description}' can not be found")
          end
          behaviour.copy_to(self)
        end

        def copy_to(eval_module) # :nodoc:
          examples.each          { |e| eval_module.examples << e; }
          before_each_parts.each { |p| eval_module.before_each_parts << p }
          after_each_parts.each  { |p| eval_module.after_each_parts << p }
          before_all_parts.each  { |p| eval_module.before_all_parts << p }
          after_all_parts.each   { |p| eval_module.after_all_parts << p }
          included_modules.each  { |m| eval_module.included_modules << m }
          eval_module.included_modules << self
        end
        
        # :call-seq:
        #   predicate_matchers[matcher_name] = method_on_object
        #   predicate_matchers[matcher_name] = [method1_on_object, method2_on_object]
        #
        # Dynamically generates a custom matcher that will match
        # a predicate on your class. RSpec provides a couple of these
        # out of the box:
        #
        #   exist (or state expectations)
        #     File.should exist("path/to/file")
        #
        #   an_instance_of (for mock argument constraints)
        #     mock.should_receive(:message).with(an_instance_of(String))
        #
        # == Examples
        #
        #   class Fish
        #     def can_swim?
        #       true
        #     end
        #   end
        #
        #   describe Fish do
        #     predicate_matchers[:swim] = :can_swim?
        #     it "should swim" do
        #       Fish.new.should swim
        #     end
        #   end
        def predicate_matchers
          @predicate_matchers ||= {:exist => :exist?, :an_instance_of => :is_a?}
        end
        
        def define_predicate_matchers(hash=nil) # :nodoc:
          if hash.nil?
            define_predicate_matchers(predicate_matchers)
            define_predicate_matchers(Spec::Runner.configuration.predicate_matchers)
          else
            hash.each_pair do |matcher_method, method_on_object|
              define_method matcher_method do |*args|
                eval("be_#{method_on_object.to_s.gsub('?','')}(*args)")
              end
            end
          end
        end
        
        # Creates an instance of Spec::DSL::Example and adds
        # it to a collection of examples of the current behaviour.
        def it(description=:__generate_description, opts={}, &block)
          examples << Example.new(description, opts, &block)
        end
        
        # Alias for it.
        def specify(description=:__generate_description, opts={}, &block)
          it(description, opts, &block)
        end

        def methods # :nodoc:
          my_methods = super
          my_methods |= behaviour_superclass.methods
          my_methods
        end

      protected

        def method_missing(method_name, *args)
          if behaviour_superclass.respond_to?(method_name)
            return execution_context_class.send(method_name, *args)
          end
          super
        end

        def before_each_proc(behaviour_type, &error_handler)
          parts = []
          parts.push(*Behaviour.before_each_parts(nil))
          parts.push(*Behaviour.before_each_parts(behaviour_type)) unless behaviour_type.nil?
          parts.push(*before_each_parts(nil))
          parts.push(*before_each_parts(behaviour_type)) unless behaviour_type.nil?
          CompositeProcBuilder.new(parts).proc(&error_handler)
        end

        def before_all_proc(behaviour_type, &error_handler)
          parts = []
          parts.push(*Behaviour.before_all_parts(nil))
          parts.push(*Behaviour.before_all_parts(behaviour_type)) unless behaviour_type.nil?
          parts.push(*before_all_parts(nil))
          parts.push(*before_all_parts(behaviour_type)) unless behaviour_type.nil?
          CompositeProcBuilder.new(parts).proc(&error_handler)
        end

        def after_all_proc(behaviour_type)
          parts = []
          parts.push(*after_all_parts(behaviour_type)) unless behaviour_type.nil?
          parts.push(*after_all_parts(nil))
          parts.push(*Behaviour.after_all_parts(behaviour_type)) unless behaviour_type.nil?
          parts.push(*Behaviour.after_all_parts(nil))
          CompositeProcBuilder.new(parts).proc
        end

        def after_each_proc(behaviour_type)
          parts = []
          parts.push(*after_each_parts(behaviour_type)) unless behaviour_type.nil?
          parts.push(*after_each_parts(nil))
          parts.push(*Behaviour.after_each_parts(behaviour_type)) unless behaviour_type.nil?
          parts.push(*Behaviour.after_each_parts(nil))
          CompositeProcBuilder.new(parts).proc
        end

      private

        def execution_context_class
          @execution_context_class ||= derive_execution_context_class_from_behaviour_superclass
        end

        def derive_execution_context_class_from_behaviour_superclass
          @execution_context_class = Class.new(behaviour_superclass)
          behaviour_superclass.spec_inherited(self) if behaviour_superclass.respond_to?(:spec_inherited)
          @execution_context_class
        end

        def behaviour_superclass
          @behaviour_superclass ||= Object
        end

        protected
        def included_modules
          @included_modules ||= [::Spec::Matchers]
        end

        def examples
          @examples ||= []
        end
      end

      module InstanceMethods
        def initialize(*args, &block) #:nodoc:
          # TODO - inheriting from TestUnit::TestCase fails without this
          # - let's figure out why and move this somewhere else
        end

        def violated(message="")
          raise Spec::Expectations::ExpectationNotMetError.new(message)
        end

        def inspect
          "[RSpec example]"
        end
        
        def pending(message)
          if block_given?
            begin
              yield
            rescue Exception => e
              raise Spec::DSL::ExamplePendingError.new(message)
            end
            raise Spec::DSL::PendingFixedError.new("Expected pending '#{message}' to fail. No Error was raised.")
          else
            raise Spec::DSL::ExamplePendingError.new(message)
          end
        end
      end
    end
  end
end
