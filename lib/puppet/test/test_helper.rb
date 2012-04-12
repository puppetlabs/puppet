module Puppet::Test
  # This class is intended to provide an API to be used by external projects
  #  when they are running tests that depend on puppet core.  This should
  #  allow us to vary the implementation details of managing puppet's state
  #  for testing, from one version of puppet to the next--without forcing
  #  the external projects to do any of that state management or be aware of
  #  the implementation details.
  #
  # For now, this consists of a few very simple signatures.  The plan is
  #  that it should be the responsibility of the puppetlabs_spec_helper
  #  to broker between external projects and this API; thus, if any
  #  hacks are required (e.g. to determine whether or not a particular)
  #  version of puppet supports this API, those hacks will be consolidated in
  #  one place and won't need to be duplicated in every external project.
  #
  # This should also alleviate the anti-pattern that we've been following,
  #  wherein each external project starts off with a copy of puppet core's
  #  test_helper.rb and is exposed to risk of that code getting out of
  #  sync with core.
  #
  # Since this class will be "library code" that ships with puppet, it does
  #  not use API from any existing test framework such as rspec.  This should
  #  theoretically allow it to be used with other unit test frameworks in the
  #  future, if desired.
  #
  # Note that in the future this API could potentially be expanded to handle
  #  other features such as "around_test", but we didn't see a compelling
  #  reason to deal with that right now.
  class TestHelper
    # Call this method once, when beginning a test run--prior to running
    #  any individual tests.
    # @return nil
    def self.before_all_tests()

    end

    # Call this method once, at the end of a test run, when no more tests
    #  will be run.
    # @return nil
    def self.after_all_tests()

    end

    # Call this method once per test, prior to execution of each invididual test.
    # @return nil
    def self.before_each_test()
      # We need to preserve the current state of all our indirection cache and
      # terminus classes.  This is pretty important, because changes to these
      # are global and lead to order dependencies in our testing.
      #
      # We go direct to the implementation because there is no safe, sane public
      # API to manage restoration of these to their default values.  This
      # should, once the value is proved, be moved to a standard API on the
      # indirector.
      #
      # To make things worse, a number of the tests stub parts of the
      # indirector.  These stubs have very specific expectations that what
      # little of the public API we could use is, well, likely to explode
      # randomly in some tests.  So, direct access.  --daniel 2011-08-30
      $saved_indirection_state = {}
      indirections = Puppet::Indirector::Indirection.send(:class_variable_get, :@@indirections)
      indirections.each do |indirector|
        $saved_indirection_state[indirector.name] = {
            :@terminus_class => indirector.instance_variable_get(:@terminus_class),
            :@cache_class    => indirector.instance_variable_get(:@cache_class)
        }
      end

      initialize_settings_before_each()

      # Longer keys are secure, but they sure make for some slow testing - both
      # in terms of generating keys, and in terms of anything the next step down
      # the line doing validation or whatever.  Most tests don't care how long
      # or secure it is, just that it exists, so these are better and faster
      # defaults, in testing only.
      #
      # I would make these even shorter, but OpenSSL doesn't support anything
      # below 512 bits.  Sad, really, because a 0 bit key would be just fine.
      Puppet[:req_bits]  = 512
      Puppet[:keylength] = 512

    end

    # Call this method once per test, after execution of each individual test.
    # @return nil
    def self.after_each_test()
      clear_settings_after_each()

      Puppet::Node::Environment.clear
      Puppet::Util::Storage.clear
      Puppet::Util::ExecutionStub.reset

      # Restore the indirector configuration.  See before hook.
      indirections = Puppet::Indirector::Indirection.send(:class_variable_get, :@@indirections)
      indirections.each do |indirector|
        $saved_indirection_state.fetch(indirector.name, {}).each do |variable, value|
          indirector.instance_variable_set(variable, value)
        end
      end
      $saved_indirection_state = nil


      # Some tests can cause us to connect, in which case the lingering
      # connection is a resource that can cause unexpected failure in later
      # tests, as well as sharing state accidentally.
      # We're testing if ActiveRecord::Base is defined because some test cases
      # may stub Puppet.features.rails? which is how we should normally
      # introspect for this functionality.
      ActiveRecord::Base.remove_connection if defined?(ActiveRecord::Base)

    end


    #########################################################################################
    # PRIVATE METHODS (not part of the public TestHelper API--do not call these from outside
    #  of this class!)
    #########################################################################################

    def self.initialize_settings_before_each()
      # these globals are set by Application
      $puppet_application_mode = nil
      $puppet_application_name = nil
      # Set the confdir and vardir to gibberish so that tests
      # have to be correctly mocked.
      Puppet[:confdir] = "/dev/null"
      Puppet[:vardir] = "/dev/null"

      # Avoid opening ports to the outside world
      Puppet[:bindaddress] = "127.0.0.1"
    end
    private_class_method :initialize_settings_before_each

    def self.clear_settings_after_each()
      Puppet.settings.clear
    end
    private_class_method :clear_settings_after_each
  end
end