dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.join(dir, 'lib')

# Don't want puppet getting the command line arguments for rake or autotest
ARGV.clear

require 'puppet'
require 'mocha'
gem 'rspec', '>=2.0.0'
require 'rspec/expectations'

# So everyone else doesn't have to include this base constant.
module PuppetSpec
  FIXTURE_DIR = File.join(dir = File.expand_path(File.dirname(__FILE__)), "fixtures") unless defined?(FIXTURE_DIR)
end

require 'pathname'
require 'tmpdir'

require 'puppet_spec/verbose'
require 'puppet_spec/files'
require 'puppet_spec/settings'
require 'puppet_spec/fixtures'
require 'puppet_spec/matchers'
require 'puppet_spec/database'
require 'monkey_patches/alias_should_to_must'
require 'monkey_patches/publicize_methods'

Pathname.glob("#{dir}/shared_behaviours/**/*.rb") do |behaviour|
  require behaviour.relative_path_from(Pathname.new(dir))
end

RSpec.configure do |config|
  include PuppetSpec::Fixtures

  config.mock_with :mocha

  config.before :each do
    # Disabling garbage collection inside each test, and only running it at
    # the end of each block, gives us an ~ 15 percent speedup, and more on
    # some platforms *cough* windows *cough* that are a little slower.
    GC.disable

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
    $old_env = ENV.to_hash

    # So is the load_path
    $old_load_path = $LOAD_PATH.dup

    # REVISIT: I think this conceals other bad tests, but I don't have time to
    # fully diagnose those right now.  When you read this, please come tell me
    # I suck for letting this float. --daniel 2011-04-21
    Signal.stubs(:trap)

    Puppet.settings.send(:initialize_everything_for_tests)

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


    @logs = []
    Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(@logs))

    @log_level = Puppet::Util::Log.level
  end

  config.after :each do
    Puppet.settings.send(:clear_everything_for_tests)
    Puppet::Node::Environment.clear
    Puppet::Util::Storage.clear
    Puppet::Util::ExecutionStub.reset

    PuppetSpec::Files.cleanup

    @logs.clear
    Puppet::Util::Log.close_all
    Puppet::Util::Log.level = @log_level

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
    $saved_indirection_state = {}

    # Restore the global process environment.  Can't just assign because this
    # is a magic variable, sadly, and doesn't do that™.  It is sufficiently
    # faster to use the compare-then-set model to avoid excessive work that it
    # justifies the complexity.  --daniel 2012-03-15
    unless ENV.to_hash == $old_env
      ENV.clear
      $old_env.each {|k, v| ENV[k] = v }
    end

    # Some tests can cause us to connect, in which case the lingering
    # connection is a resource that can cause unexpected failure in later
    # tests, as well as sharing state accidentally.
    # We're testing if ActiveRecord::Base is defined because some test cases
    # may stub Puppet.features.rails? which is how we should normally
    # introspect for this functionality.
    ActiveRecord::Base.remove_connection if defined?(ActiveRecord::Base)

    # Restore the load_path late, to avoid messing with stubs from the test.
    $LOAD_PATH.clear
    $old_load_path.each {|x| $LOAD_PATH << x }

    # This will perform a GC between tests, but only if actually required.  We
    # experimented with forcing a GC run, and that was less efficient than
    # just letting it run all the time.
    GC.enable
  end
end
