unless defined?(SPEC_HELPER_IS_LOADED)
SPEC_HELPER_IS_LOADED = 1

dir = File.expand_path(File.dirname(__FILE__))

$LOAD_PATH.unshift("#{dir}/")
$LOAD_PATH.unshift("#{dir}/lib") # a spec-specific test lib dir
$LOAD_PATH.unshift("#{dir}/../lib")

# Don't want puppet getting the command line arguments for rake or autotest
ARGV.clear

require 'puppet'
require 'mocha'
gem 'rspec', '>=2.0.0'

# So everyone else doesn't have to include this base constant.
module PuppetSpec
  FIXTURE_DIR = File.join(dir = File.expand_path(File.dirname(__FILE__)), "fixtures") unless defined?(FIXTURE_DIR)
end

require 'pathname'
require 'tmpdir'

require 'lib/puppet_spec/verbose'
require 'lib/puppet_spec/files'
require 'lib/puppet_spec/fixtures'
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

    # these globals are set by Application
    $puppet_application_mode = nil
    $puppet_application_name = nil
    Signal.stubs(:trap)

    # Set the confdir and vardir to gibberish so that tests
    # have to be correctly mocked.
    Puppet[:confdir] = "/dev/null"
    Puppet[:vardir] = "/dev/null"

    # Avoid opening ports to the outside world
    Puppet.settings[:bindaddress] = "127.0.0.1"

    @logs = []
    Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(@logs))
  end

  config.after :each do
    Puppet.settings.clear
    Puppet::Node::Environment.clear
    Puppet::Util::Storage.clear
    Puppet::Util::ExecutionStub.reset

    PuppetSpec::Files.cleanup

    @logs.clear
    Puppet::Util::Log.close_all

    GC.enable
  end
end

# close of the "don't evaluate twice" mess.
end
