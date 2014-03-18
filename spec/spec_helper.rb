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
  exclude_filters = {:broken => true}
  exclude_filters[:benchmark] = true unless ENV['BENCHMARK']
  config.filter_run_excluding exclude_filters

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
    if ENV['PROFILE'] == 'all'
      require 'ruby-prof'
      RubyProf.start
    end
  end

  config.after :all do
    if ENV['PROFILE'] == 'all'
      require 'ruby-prof'
      result = RubyProf.stop
      printer = RubyProf::CallTreePrinter.new(result)
      open(File.join(ENV['PROFILEOUT'],"callgrind.all.#{Time.now.to_i}.trace"), "w") do |f|
        printer.print(f)
      end
    end

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

    base = PuppetSpec::Files.tmpdir('tmp_settings')
    Puppet[:vardir] = File.join(base, 'var')
    Puppet[:confdir] = File.join(base, 'etc')
    Puppet[:logdir] = "$vardir/log"
    Puppet[:rundir] = "$vardir/run"
    Puppet[:hiera_config] = File.join(base, 'hiera')

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

    # return to original tmpdir
    ENV['TMPDIR'] = oldtmpdir
    FileUtils.rm_rf(tmpdir)
  end

  if ENV['PROFILE']
    require 'ruby-prof'

    def profile
      result = RubyProf.profile { yield }
      name = example.metadata[:full_description].downcase.gsub(/[^a-z0-9_-]/, "-").gsub(/-+/, "-")
      printer = RubyProf::CallTreePrinter.new(result)
      open(File.join(ENV['PROFILEOUT'],"callgrind.#{name}.#{Time.now.to_i}.trace"), "w") do |f|
        printer.print(f)
      end
    end

    config.around(:each) do |example|
      if ENV['PROFILE'] == 'each' or (example.metadata[:profile] and ENV['PROFILE'])
        profile { example.run }
      else
        example.run
      end
    end
  end
end

DIGEST_ALGORITHMS_TO_TRY = [nil, 'md5', 'sha256']
# see lib/puppet/defaults.rb
DEFAULT_DIGEST_ALGORITHM = 'md5'

shared_context('with various digest_algorithm settings',
               :uses_checksums => true) do
  # Drop-in replacement for the it class method, which makes an
  # example group containing one example for each value of the
  # :digest_algorithm Puppet setting given in
  # DIGEST_ALGORITHMS_TO_TRY.
  def self.using_checksums_it desc=nil, *args, &block
    # refer to rspec/core/example_group.rb
    group = describe("when digest_algorithm is") do
      DIGEST_ALGORITHMS_TO_TRY.each do |the_algo|
        
        describe(the_algo ? "set to #{the_algo}" : "unset",
                 :digest_algorithm => the_algo) do
          it(desc, *args, &block)
        end
      end
    end
    group.metadata[:shared_group_name] = desc
    group
  end

  # Drop-in replacement for the describe class method, which makes an
  # example group containing one copy of the given group for each
  # value of the :digest_algorithm Puppet setting given in
  # DIGEST_ALGORITHMS_TO_TRY.
  def self.using_checksums_describe *args, &example_group_block
    group = describe("") do
      DIGEST_ALGORITHMS_TO_TRY.each do |the_algo|
        describe("when digest_algorithm is " +
                 (the_algo ? "set to #{the_algo}" : "unset"),
                 :digest_algorithm => the_algo) do
          class << self
            alias_method :using_checksums_it, :it
          end
          describe *args, &example_group_block
        end
      end
    end
  end
end
    
DIGEST_ALGORITHMS_TO_TRY.each do |the_algo|
  shared_context("when digest_algorithm is set to #{the_algo || 'nil'}",
                 :digest_algorithm => the_algo) do
    before do
      Puppet[:digest_algorithm] = the_algo
    end
    after do
      Puppet[:digest_algorithm] = nil
    end
    let(:algo) { the_algo || DEFAULT_DIGEST_ALGORITHM }
    let(:checksums) { {
      "my\r\ncontents" => {
        'md5'    => 'f0d7d4e480ad698ed56aeec8b6bd6dea',
        'sha256' => '409a11465ed0938227128b1756c677a8480a8b84814f1963853775e15a74d4b4',
      },
      "other stuff" => {
        'md5'    => 'c0133c37ea4b55af2ade92e1f1337568',
        'sha256' => '71e19d6834b179eff0012516fa1397c392d5644a3438644e3f23634095a84974',
      },
      } }
    let(:bucket_dirs) { {
      "my\r\ncontents" => {
        'md5'    => 'f/0/d/7/d/4/e/4/f0d7d4e480ad698ed56aeec8b6bd6dea',
        'sha256' => '4/0/9/a/1/1/4/6/409a11465ed0938227128b1756c677a8480a8b84814f1963853775e15a74d4b4',
      },
      "other stuff" => {
        'md5'    => 'c/0/1/3/3/c/3/7/c0133c37ea4b55af2ade92e1f1337568',
        'sha256' => '7/1/e/1/9/d/6/8/71e19d6834b179eff0012516fa1397c392d5644a3438644e3f23634095a84974',
      }
      } }
    let(:plaintext) { "my\r\ncontents" }
    let(:checksum) { checksums[plaintext][algo] }
    let(:bucket_dir) { bucket_dirs[plaintext][algo] }
    let(:not_bucketed_plaintext) { "other stuff" }
    let(:not_bucketed_checksum) { checksums[not_bucketed_plaintext][algo] }
    let(:not_bucketed_bucket_dir) { checksums[not_bucketed_plaintext][algo] }
    let(:checksums_class) { Class.new { include Puppet::Util::Checksums } }
    let(:checksums_instance) { checksums_class.new }
    def digest *args
      checksums_instance.method(algo).call *args
    end
  end
end
