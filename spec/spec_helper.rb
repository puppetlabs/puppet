# NOTE: a lot of the stuff in this file is duplicated in the "puppet_spec_helper" in the project
#  puppetlabs_spec_helper.  We should probably eat our own dog food and get rid of most of this from here,
#  and have the puppet core itself use puppetlabs_spec_helper

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
require 'fileutils'

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

  # Examples or groups can selectively tag themselves as broken.
  # For example;
  #
  # rbv = "#{RUBY_VERSION}-p#{RbConfig::CONFIG['PATCHLEVEL']}"
  # describe "mostly working", :broken => false unless rbv == "1.9.3-p327" do
  #  it "parses a valid IP" do
  #    IPAddr.new("::2:3:4:5:6:7:8")
  #  end
  # end
  config.filter_run_excluding :broken => true

  config.mock_with :mocha

  tmpdir = Dir.mktmpdir("rspecrun")
  oldtmpdir = Dir.tmpdir()
  ENV['TMPDIR'] = tmpdir

  if Puppet::Util::Platform.windows?
    config.output_stream = $stdout
    config.error_stream = $stderr

    config.formatters.each do |f|
      if not f.instance_variable_get(:@output).kind_of?(::File)
        f.instance_variable_set(:@output, $stdout)
      end
    end
  end

  Puppet::Test::TestHelper.initialize

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
    # Clean up switch of TMPDIR, don't know if needed after this, so needs to reset it
    # to old before removing it
    ENV['TMPDIR'] = oldtmpdir
    FileUtils.rm_rf(tmpdir) if File.exists?(tmpdir) && tmpdir.to_s.start_with?(oldtmpdir)
  end
end
