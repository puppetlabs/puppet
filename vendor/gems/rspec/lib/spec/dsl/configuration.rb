module Spec
  module DSL
    class Configuration
      
      # Chooses what mock framework to use. Example:
      #
      #   Spec::Runner.configure do |config|
      #     config.mock_with :rspec, :mocha, :flexmock, or :rr
      #   end
      #
      # To use any other mock framework, you'll have to provide
      # your own adapter. This is simply a module that responds to
      # setup_mocks_for_rspec, verify_mocks_for_rspec and teardown_mocks_for_rspec.
      # These are your hooks into the lifecycle of a given example. RSpec will
      # call setup_mocks_for_rspec before running anything else in each Example.
      # After executing the #after methods, RSpec will then call verify_mocks_for_rspec
      # and teardown_mocks_for_rspec (this is guaranteed to run even if there are
      # failures in verify_mocks_for_rspec).
      #
      # Once you've defined this module, you can pass that to mock_with:
      #
      #   Spec::Runner.configure do |config|
      #     config.mock_with MyMockFrameworkAdapter
      #   end
      #
      def mock_with(mock_framework)
        @mock_framework = case mock_framework
        when Symbol
          mock_framework_path(mock_framework.to_s)
        else
          mock_framework
        end
      end
      
      def mock_framework # :nodoc:
        @mock_framework ||= mock_framework_path("rspec")
      end
      
      # Declares modules to be included in all behaviours (<tt>describe</tt> blocks).
      #
      #   config.include(My::Bottle, My::Cup)
      #
      # If you want to restrict the inclusion to a subset of all the behaviours then
      # specify this in a Hash as the last argument:
      #
      #   config.include(My::Pony, My::Horse, :behaviour_type => :farm)
      #
      # Only behaviours that have that type will get the modules included:
      #
      #   describe "Downtown", :behaviour_type => :city do
      #     # Will *not* get My::Pony and My::Horse included
      #   end
      #
      #   describe "Old Mac Donald", :behaviour_type => :farm do
      #     # *Will* get My::Pony and My::Horse included
      #   end
      #
      def include(*args)
        args << {} unless Hash === args.last
        modules, options = args_and_options(*args)
        required_behaviour_type = options[:behaviour_type]
        required_behaviour_type = required_behaviour_type.to_sym unless required_behaviour_type.nil?
        @modules ||= {}
        @modules[required_behaviour_type] ||= []
        @modules[required_behaviour_type] += modules
      end

      def modules_for(required_behaviour_type) #:nodoc:
        @modules ||= {}
        modules = @modules[nil] || [] # general ones
        modules << @modules[required_behaviour_type.to_sym] unless required_behaviour_type.nil?
        modules.uniq.compact
      end
      
      # This is just for cleanup in RSpec's own examples
      def exclude(*modules) #:nodoc:
        @modules.each do |behaviour_type, mods|
          modules.each{|m| mods.delete(m)}
        end
      end
      
      # Defines global predicate matchers. Example:
      #
      #   config.predicate_matchers[:swim] = :can_swim?
      #
      # This makes it possible to say:
      #
      #   person.should swim # passes if person.should_swim? returns true
      #
      def predicate_matchers
        @predicate_matchers ||= {}
      end
      
      # Prepends a global <tt>before</tt> block to all behaviours.
      # See #append_before for filtering semantics.
      def prepend_before(*args, &proc)
        Behaviour.prepend_before(*args, &proc)
      end
      # Appends a global <tt>before</tt> block to all behaviours.
      #
      # If you want to restrict the block to a subset of all the behaviours then
      # specify this in a Hash as the last argument:
      #
      #   config.prepend_before(:all, :behaviour_type => :farm)
      #
      # or
      #
      #   config.prepend_before(:behaviour_type => :farm)
      #
      def append_before(*args, &proc)
        Behaviour.append_before(*args, &proc)
      end
      alias_method :before, :append_before

      # Prepends a global <tt>after</tt> block to all behaviours.
      # See #append_before for filtering semantics.
      def prepend_after(*args, &proc)
        Behaviour.prepend_after(*args, &proc)
      end
      alias_method :after, :prepend_after
      # Appends a global <tt>after</tt> block to all behaviours.
      # See #append_before for filtering semantics.
      def append_after(*args, &proc)
        Behaviour.append_after(*args, &proc)
      end

    private
    
      def mock_framework_path(framework_name)
        File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "plugins", "mock_frameworks", framework_name))
      end
      
    end
  end
end
