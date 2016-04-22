require 'puppet/indirector/data_binding/hiera'

require 'tmpdir'
require 'fileutils'

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
    # Call this method once, as early as possible, such as before loading tests
    # that call Puppet.
    # @return nil
    def self.initialize()
      # This meta class instance variable is used as a guard to ensure that
      # before_each, and after_each are only called once. This problem occurs
      # when there are more than one puppet test infrastructure "orchestrator in us.
      # The use of both puppetabs-spec_helper, and rodjek-rspec_puppet will cause
      # two resets of the puppet environment, and will cause problem rolling back to
      # a known point as there is no way to differentiate where the calls are coming
      # from. See more information in #before_each_test, and #after_each_test
      # Note that the variable is only initialized to 0 if nil. This is important
      # as more than one orchestrator will call initialize. A second call can not
      # simply set it to 0 since that would potentially destroy an active guard.
      #
      @@reentry_count ||= 0

      @environmentpath = Dir.mktmpdir('environments')
      Dir.mkdir("#{@environmentpath}/production")
      owner = Process.pid
      Puppet.push_context(Puppet.base_context({
        :environmentpath => @environmentpath,
        :basemodulepath => "",
      }), "Initial for specs")
      Puppet::Parser::Functions.reset

      ObjectSpace.define_finalizer(Puppet.lookup(:environments), proc {
        if Process.pid == owner
          FileUtils.rm_rf(@environmentpath)
        end
      })
      Puppet::SSL::Oids.register_puppet_oids
    end

    # Call this method once, when beginning a test run--prior to running
    #  any individual tests.
    # @return nil
    def self.before_all_tests()
      # Make sure that all of the setup is also done for any before(:all) blocks
    end

    # Call this method once, at the end of a test run, when no more tests
    #  will be run.
    # @return nil
    def self.after_all_tests()
    end

    # The name of the rollback mark used in the Puppet.context. This is what
    # the test infrastructure returns to for each test.
    #
    ROLLBACK_MARK = "initial testing state"

    # Call this method once per test, prior to execution of each invididual test.
    # @return nil
    def self.before_each_test()
      # When using both rspec-puppet and puppet-rspec-helper, there are two packages trying
      # to be helpful and orchestrate the callback sequence. We let only the first win, the
      # second callback results in a no-op.
      # Likewise when entering after_each_test(), a check is made to make tear down happen
      # only once.
      #
      return unless @@reentry_count == 0
      @@reentry_count = 1

      Puppet.mark_context(ROLLBACK_MARK)

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

      # The process environment is a shared, persistent resource.
      # Can't use Puppet.features.microsoft_windows? as it may be mocked out in a test.  This can cause test recurring test failures
      if (!!File::ALT_SEPARATOR)
        mode = :windows
      else
        mode = :posix
      end
      $old_env = Puppet::Util.get_environment(mode)

      # So is the load_path
      $old_load_path = $LOAD_PATH.dup

      initialize_settings_before_each()

      Puppet.push_context(
        {
          :trusted_information =>
            Puppet::Context::TrustedInformation.new('local', 'testing', {}),
        },
        "Context for specs")

      Puppet::Parser::Functions.reset
      Puppet::Application.clear!
      Puppet::Util::Profiler.clear

      Puppet.clear_deprecation_warnings

      Puppet::DataBinding::Hiera.instance_variable_set("@hiera", nil)
    end

    # Call this method once per test, after execution of each individual test.
    # @return nil
    def self.after_each_test()
      # Ensure that a matching tear down only happens once per completed setup
      # (see #before_each_test).
      return unless @@reentry_count == 1
      @@reentry_count = 0

      Puppet.settings.send(:clear_everything_for_tests)

      Puppet::Util::Storage.clear
      Puppet::Util::ExecutionStub.reset

      Puppet.clear_deprecation_warnings

      # uncommenting and manipulating this can be useful when tracking down calls to deprecated code
      #Puppet.log_deprecations_to_file("deprecations.txt", /^Puppet::Util.exec/)

      # Restore the indirector configuration.  See before hook.
      indirections = Puppet::Indirector::Indirection.send(:class_variable_get, :@@indirections)
      indirections.each do |indirector|
        $saved_indirection_state.fetch(indirector.name, {}).each do |variable, value|
          indirector.instance_variable_set(variable, value)
        end
      end
      $saved_indirection_state = nil

      # Can't use Puppet.features.microsoft_windows? as it may be mocked out in a test.  This can cause test recurring test failures
      if (!!File::ALT_SEPARATOR)
        mode = :windows
      else
        mode = :posix
      end
      # Restore the global process environment.  Can't just assign because this
      # is a magic variable, sadly, and doesn't do that™.  It is sufficiently
      # faster to use the compare-then-set model to avoid excessive work that it
      # justifies the complexity.  --daniel 2012-03-15
      unless Puppet::Util.get_environment(mode) == $old_env
        Puppet::Util.clear_environment(mode)
        $old_env.each {|k, v| Puppet::Util.set_env(k, v, mode) }
      end

      # Restore the load_path late, to avoid messing with stubs from the test.
      $LOAD_PATH.clear
      $old_load_path.each {|x| $LOAD_PATH << x }

      Puppet.rollback_context(ROLLBACK_MARK)
    end


    #########################################################################################
    # PRIVATE METHODS (not part of the public TestHelper API--do not call these from outside
    #  of this class!)
    #########################################################################################

    def self.app_defaults_for_tests()
      {
          :logdir     => "/dev/null",
          :confdir    => "/dev/null",
          :codedir    => "/dev/null",
          :vardir     => "/dev/null",
          :rundir     => "/dev/null",
          :hiera_config => "/dev/null",
      }
    end
    private_class_method :app_defaults_for_tests

    def self.initialize_settings_before_each()
      Puppet.settings.preferred_run_mode = "user"
      # Initialize "app defaults" settings to a good set of test values
      Puppet.settings.initialize_app_defaults(app_defaults_for_tests)

      # Avoid opening ports to the outside world
      Puppet.settings[:bindaddress] = "127.0.0.1"

      # We don't want to depend upon the reported domain name of the
      # machine running the tests, nor upon the DNS setup of that
      # domain.
      Puppet.settings[:use_srv_records] = false

      # Longer keys are secure, but they sure make for some slow testing - both
      # in terms of generating keys, and in terms of anything the next step down
      # the line doing validation or whatever.  Most tests don't care how long
      # or secure it is, just that it exists, so these are better and faster
      # defaults, in testing only.
      #
      # I would make these even shorter, but OpenSSL doesn't support anything
      # below 512 bits.  Sad, really, because a 0 bit key would be just fine.
      Puppet[:keylength] = 512

      # Although we setup a testing context during initialization, some tests
      # will end up creating their own context using the real context objects
      # and use the setting for the environments. In order to avoid those tests
      # having to deal with a missing environmentpath we can just set it right
      # here.
      Puppet[:environmentpath] = @environmentpath
      Puppet[:environment_timeout] = 0
    end
    private_class_method :initialize_settings_before_each
  end
end
