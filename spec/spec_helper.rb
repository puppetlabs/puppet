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
require 'puppet_spec/fixtures'
require 'puppet_spec/matchers'
require 'monkey_patches/alias_should_to_must'
require 'monkey_patches/publicize_methods'

Pathname.glob("#{dir}/shared_behaviours/**/*.rb") do |behaviour|
  require behaviour.relative_path_from(Pathname.new(dir))
end

RSpec.configure do |config|
  include PuppetSpec::Fixtures

  config.mock_with :mocha

  config.before :each do
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

    # these globals are set by Application
    $puppet_application_mode = nil
    $puppet_application_name = nil

    # REVISIT: I think this conceals other bad tests, but I don't have time to
    # fully diagnose those right now.  When you read this, please come tell me
    # I suck for letting this float. --daniel 2011-04-21
    Signal.stubs(:trap)

    # Set the confdir and vardir to gibberish so that tests
    # have to be correctly mocked.
    Puppet[:confdir] = "/dev/null"
    Puppet[:vardir] = "/dev/null"

    # Avoid opening ports to the outside world
    Puppet.settings[:bindaddress] = "127.0.0.1"

    @logs = []
    Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(@logs))

    @log_level = Puppet::Util::Log.level
  end

  config.after :each do
    Puppet.settings.clear
    Puppet::Node::Environment.clear
    Puppet::Util::Storage.clear
    Puppet::Util::ExecutionStub.reset

    PuppetSpec::Files.cleanup

    @logs.clear
    Puppet::Util::Log.close_all
    Puppet::Util::Log.level = @log_level

    # Restore the indirector configuration.  See before hook.
    indirections = Puppet::Indirector::Indirection.send(:class_variable_get, :@@indirections)
    indirections.each do |indirector|
      $saved_indirection_state.fetch(indirector.name, {}).each do |variable, value|
        indirector.instance_variable_set(variable, value)
      end
    end
    $saved_indirection_state = nil

    GC.enable
  end
end
