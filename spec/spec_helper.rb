# NOTE: a lot of the stuff in this file is duplicated in the "puppet_spec_helper" in the project
#  puppetlabs_spec_helper.  We should probably eat our own dog food and get rid of most of this from here,
#  and have the puppet core itself use puppetlabs_spec_helper
begin
  require 'simplecov'

  SimpleCov.start do
    add_filter "/spec/"
    add_group "DSL",             "lib/puppet/dsl"
    add_group "Agent",           "lib/puppet/agent"
    add_group "Application",     "lib/puppet/application"
    add_group "Configurer",      "lib/puppet/configurer"
    add_group "External",        "lib/puppet/external"
    add_group "Face",            "lib/puppet/face"
    add_group "Feature",         "lib/puppet/feature"
    add_group "File Bucket",     "lib/puppet/file_bucket"
    add_group "File Collection", "lib/puppet/file_collection"
    add_group "File Serving",    "lib/puppet/file_serving"
    add_group "Forge",           "lib/puppet/forge"
    add_group "Indirector",      "lib/puppet/indirector"
    add_group "Interface",       "lib/puppet/interface"
    add_group "MetaType",        "lib/puppet/metatype"
    add_group "Module Tool",     "lib/puppet/module_tool"
    add_group "Network",         "lib/puppet/network"
    add_group "Node",            "lib/puppet/node"
    add_group "Parameter",       "lib/puppet/parameter"
    add_group "Parser",          "lib/puppet/parser"
    add_group "Property",        "lib/puppet/property"
    add_group "Provider",        "lib/puppet/provider"
    add_group "Rails",           "lib/puppet/rails"
    add_group "Reference",       "lib/puppet/reference"
    add_group "Reports",         "lib/puppet/reports"
    add_group "Resource",        "lib/puppet/resource"
    add_group "Settings",        "lib/puppet/settings"
    add_group "SSL",             "lib/puppet/ssl"
    add_group "Test",            "lib/puppet/test"
    add_group "Transaction",     "lib/puppet/transaction"
    add_group "Type",            "lib/puppet/type"
    add_group "Util",            "lib/puppet/util"
  end
rescue LoadError
  puts "No coverage for you..."
end


dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.join(dir, 'lib')

# Don't want puppet getting the command line arguments for rake or autotest
ARGV.clear

begin
  require 'rubygems'
rescue LoadError
end

require 'puppet'
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
require 'puppet/test/test_helper'

Pathname.glob("#{dir}/shared_contexts/*.rb") do |file|
  require file.relative_path_from(Pathname.new(dir))
end

Pathname.glob("#{dir}/shared_behaviours/**/*.rb") do |behaviour|
  require behaviour.relative_path_from(Pathname.new(dir))
end

RSpec.configure do |config|
  include PuppetSpec::Fixtures

  config.mock_with :mocha

  if Puppet::Util::Platform.windows?
    config.output_stream = $stdout
    config.error_stream = $stderr
    config.formatters.each { |f| f.instance_variable_set(:@output, $stdout) }
  end

  config.before :all do
    Puppet::Test::TestHelper.before_all_tests()
  end

  config.after :all do
    Puppet::Test::TestHelper.after_all_tests()
  end

  config.before :each do
    # Disabling garbage collection inside each test, and only running it at
    # the end of each block, gives us an ~ 15 percent speedup, and more on
    # some platforms *cough* windows *cough* that are a little slower.
    GC.disable

    # REVISIT: I think this conceals other bad tests, but I don't have time to
    # fully diagnose those right now.  When you read this, please come tell me
    # I suck for letting this float. --daniel 2011-04-21
    Signal.stubs(:trap)


    # TODO: in a more sane world, we'd move this logging redirection into our TestHelper class.
    #  Without doing so, external projects will all have to roll their own solution for
    #  redirecting logging, and for validating expected log messages.  However, because the
    #  current implementation of this involves creating an instance variable "@logs" on
    #  EVERY SINGLE TEST CLASS, and because there are over 1300 tests that are written to expect
    #  this instance variable to be available--we can't easily solve this problem right now.
    #
    # redirecting logging away from console, because otherwise the test output will be
    #  obscured by all of the log output
    @logs = []
    Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(@logs))

    @log_level = Puppet::Util::Log.level

    Puppet::Test::TestHelper.before_each_test()

  end

  config.after :each do
    Puppet::Test::TestHelper.after_each_test()

    # TODO: would like to move this into puppetlabs_spec_helper, but there are namespace issues at the moment.
    PuppetSpec::Files.cleanup

    # TODO: this should be abstracted in the future--see comments above the '@logs' block in the
    #  "before" code above.
    #
    # clean up after the logging changes that we made before each test.
    @logs.clear
    Puppet::Util::Log.close_all
    Puppet::Util::Log.level = @log_level

    # This will perform a GC between tests, but only if actually required.  We
    # experimented with forcing a GC run, and that was less efficient than
    # just letting it run all the time.
    GC.enable
  end

  config.after :suite do
    # Log the spec order to a file, but only if the LOG_SPEC_ORDER environment variable is
    #  set.  This should be enabled on Jenkins runs, as it can be used with Nick L.'s bisect
    #  script to help identify and debug order-dependent spec failures.
    if ENV['LOG_SPEC_ORDER']
      File.open("./spec_order.txt", "w") do |logfile|
        config.instance_variable_get(:@files_to_run).each { |f| logfile.puts f }
      end
    end
  end
end

