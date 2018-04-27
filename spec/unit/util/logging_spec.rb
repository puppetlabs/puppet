#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/logging'

class LoggingTester
  include Puppet::Util::Logging
end

describe Puppet::Util::Logging do
  before do
    @logger = LoggingTester.new
  end

  Puppet::Util::Log.eachlevel do |level|
    it "should have a method for sending '#{level}' logs" do
      expect(@logger).to respond_to(level)
    end
  end

  it "should have a method for sending a log with a specified log level" do
    @logger.expects(:to_s).returns "I'm a string!"
    Puppet::Util::Log.expects(:create).with { |args| args[:source] == "I'm a string!" and args[:level] == "loglevel" and args[:message] == "mymessage" }

    @logger.send_log "loglevel", "mymessage"
  end

  describe "when sending a log" do
    it "should use the Log's 'create' entrance method" do
      Puppet::Util::Log.expects(:create)

      @logger.notice "foo"
    end

    it "should send itself converted to a string as the log source" do
      @logger.expects(:to_s).returns "I'm a string!"
      Puppet::Util::Log.expects(:create).with { |args| args[:source] == "I'm a string!" }

      @logger.notice "foo"
    end

    it "should queue logs sent without a specified destination" do
      Puppet::Util::Log.close_all
      Puppet::Util::Log.expects(:queuemessage)

      @logger.notice "foo"
    end

    it "should use the path of any provided resource type" do
      resource = Puppet::Type.type(:host).new :name => "foo"

      resource.expects(:path).returns "/path/to/host".to_sym

      Puppet::Util::Log.expects(:create).with { |args| args[:source] == "/path/to/host" }

      resource.notice "foo"
    end

    it "should use the path of any provided resource parameter" do
      resource = Puppet::Type.type(:host).new :name => "foo"

      param = resource.parameter(:name)

      param.expects(:path).returns "/path/to/param".to_sym

      Puppet::Util::Log.expects(:create).with { |args| args[:source] == "/path/to/param" }

      param.notice "foo"
    end

    it "should send the provided argument as the log message" do
      Puppet::Util::Log.expects(:create).with { |args| args[:message] == "foo" }

      @logger.notice "foo"
    end

    it "should join any provided arguments into a single string for the message" do
      Puppet::Util::Log.expects(:create).with { |args| args[:message] == "foo bar baz" }

      @logger.notice ["foo", "bar", "baz"]
    end

    [:file, :line, :tags].each do |attr|
      it "should include #{attr} if available" do
        @logger.singleton_class.send(:attr_accessor, attr)

        @logger.send(attr.to_s + "=", "myval")

        Puppet::Util::Log.expects(:create).with { |args| args[attr] == "myval" }
        @logger.notice "foo"
      end
    end
  end

  describe "when sending a deprecation warning" do
    it "does not log a message when deprecation warnings are disabled" do
      Puppet.expects(:[]).with(:disable_warnings).returns %w[deprecations]
      @logger.expects(:warning).never
      @logger.deprecation_warning 'foo'
    end

    it "logs the message with warn" do
      @logger.expects(:warning).with do |msg|
        msg =~ /^foo\n/
      end
      @logger.deprecation_warning 'foo'
    end

    it "only logs each offending line once" do
      @logger.expects(:warning).with do |msg|
        msg =~ /^foo\n/
      end .once
      5.times { @logger.deprecation_warning 'foo' }
    end

    it "ensures that deprecations from same origin are logged if their keys differ" do
      @logger.expects(:warning).with(regexp_matches(/deprecated foo/)).times(5)
      5.times { |i| @logger.deprecation_warning('deprecated foo', :key => "foo#{i}") }
    end

    it "does not duplicate deprecations for a given key" do
      @logger.expects(:warning).with(regexp_matches(/deprecated foo/)).once
      5.times { @logger.deprecation_warning('deprecated foo', :key => 'foo-msg') }
    end

    it "only logs the first 100 messages" do
      (1..100).each { |i|
        @logger.expects(:warning).with do |msg|
          msg =~ /^#{i}\n/
        end .once
        # since the deprecation warning will only log each offending line once, we have to do some tomfoolery
        # here in order to make it think each of these calls is coming from a unique call stack; we're basically
        # mocking the method that it would normally use to find the call stack.
        @logger.expects(:get_deprecation_offender).returns(["deprecation log count test ##{i}"])
        @logger.deprecation_warning i
      }
      @logger.expects(:warning).with(101).never
      @logger.deprecation_warning 101
    end
  end

  describe "when sending a puppet_deprecation_warning" do
    it "requires file and line or key options" do
      expect do
        @logger.puppet_deprecation_warning("foo")
      end.to raise_error(Puppet::DevError, /Need either :file and :line, or :key/)
      expect do
        @logger.puppet_deprecation_warning("foo", :file => 'bar')
      end.to raise_error(Puppet::DevError, /Need either :file and :line, or :key/)
      expect do
        @logger.puppet_deprecation_warning("foo", :key => 'akey')
        @logger.puppet_deprecation_warning("foo", :file => 'afile', :line => 1)
      end.to_not raise_error
    end

    it "warns with file and line" do
      @logger.expects(:warning).with(regexp_matches(/deprecated foo.*\(file: afile, line: 5\)/m))
      @logger.puppet_deprecation_warning("deprecated foo", :file => 'afile', :line => 5)
    end

    it "warns keyed from file and line" do
      @logger.expects(:warning).with(regexp_matches(/deprecated foo.*\(file: afile, line: 5\)/m)).once
      5.times do
        @logger.puppet_deprecation_warning("deprecated foo", :file => 'afile', :line => 5)
      end
    end

    it "warns with separate key only once regardless of file and line" do
      @logger.expects(:warning).with(regexp_matches(/deprecated foo.*\(file: afile, line: 5\)/m)).once
      @logger.puppet_deprecation_warning("deprecated foo", :key => 'some_key', :file => 'afile', :line => 5)
      @logger.puppet_deprecation_warning("deprecated foo", :key => 'some_key', :file => 'bfile', :line => 3)
    end

    it "warns with key but no file and line" do
      @logger.expects(:warning).with(regexp_matches(/deprecated foo.*\(file: unknown, line: unknown\)/m))
      @logger.puppet_deprecation_warning("deprecated foo", :key => 'some_key')
    end
  end

  describe "when sending a warn_once" do
    before(:each) {
      @logger.clear_deprecation_warnings
    }
    after(:each) {
      # this is required because of bugs in Mocha whe tearing down expectations for each test
      # why it works elsewhere is a mystery.
      @logger.unstub(:send_log)
    }

    it "warns with file when only file is given" do
      @logger.expects(:send_log).with(:warning, regexp_matches(/wet paint.*\(file: aFile\)/m))
      @logger.warn_once('kind', 'wp', "wet paint", 'aFile')
    end

    it "warns with unknown file and line when only line is given" do
      @logger.expects(:send_log).with(:warning, regexp_matches(/wet paint.*\(line: 5\)/m))
      @logger.warn_once('kind', 'wp', "wet paint", nil, 5)
    end

    it "warns with file and line when both are given" do
      @logger.expects(:send_log).with(:warning, regexp_matches(/wet paint.*\(file: aFile, line: 5\)/m))
      @logger.warn_once('kind', 'wp', "wet paint",'aFile', 5)
    end

    it "warns once per key" do
      @logger.expects(:send_log).with(:warning, regexp_matches(/wet paint.*/m)).once
      5.times do
        @logger.warn_once('kind', 'wp', "wet paint")
      end
    end

    Puppet::Util::Log.eachlevel do |level|
      it "can use log level #{level}" do
        @logger.expects(:send_log).with(level, regexp_matches(/wet paint.*/m)).once
        5.times do
          @logger.warn_once('kind', 'wp', "wet paint", nil, nil, level)
        end
      end
    end
  end

  describe "does not warn about undefined variables when disabled_warnings says so" do
    let(:logger) { LoggingTester.new }

    around(:each) do |example|
      Puppet.settings.initialize_global_settings
      logger.clear_deprecation_warnings
      Puppet[:disable_warnings] = ['undefined_variables']
      example.run
      Puppet[:disable_warnings] = []
    end

    after(:each) do
      logger.unstub(:send_log)
    end

    it "does not produce warning if kind is disabled" do
      logger.expects(:send_log).never
      logger.warn_once('undefined_variables', 'wp', "wet paint")
    end
  end

  describe "warns about undefined variables when deprecations are in disabled_warnings" do
    let(:logger) { LoggingTester.new }

    around(:each) do |example|
      Puppet.settings.initialize_global_settings
      logger.clear_deprecation_warnings
      Puppet[:disable_warnings] = ['deprecations']
      example.run
      Puppet[:disable_warnings] = []
    end

    after(:each) do
      logger.unstub(:send_log)
    end

    it "produces warning even if deprecation warnings are disabled " do
      logger.expects(:send_log).with(:warning, regexp_matches(/wet paint/)).once
      logger.warn_once('undefined_variables', 'wp', "wet paint")
    end
  end

  describe "when formatting exceptions" do
    it "should be able to format a chain of exceptions" do
      exc3 = Puppet::Error.new("original")
      exc3.set_backtrace(["1.rb:4:in `a'","2.rb:2:in `b'","3.rb:1"])
      exc2 = Puppet::Error.new("second", exc3)
      exc2.set_backtrace(["4.rb:8:in `c'","5.rb:1:in `d'","6.rb:3"])
      exc1 = Puppet::Error.new("third", exc2)
      exc1.set_backtrace(["7.rb:31:in `e'","8.rb:22:in `f'","9.rb:9"])
      # whoa ugly
      expect(@logger.format_exception(exc1)).to match(/third
.*7\.rb:31:in `e'
.*8\.rb:22:in `f'
.*9\.rb:9
Wrapped exception:
second
.*4\.rb:8:in `c'
.*5\.rb:1:in `d'
.*6\.rb:3
Wrapped exception:
original
.*1\.rb:4:in `a'
.*2\.rb:2:in `b'
.*3\.rb:1/)
    end
  end

  describe 'when Facter' do
    after :each do
      # Unstub these calls as there is global code run after
      # each spec that may reset the log level to debug
      Facter.unstub(:respond_to?)
      Facter.unstub(:debugging)
    end

    describe 'does not support debugging' do
      before :each do
        Facter.stubs(:respond_to?).with(:debugging).returns false
        Facter.stubs(:debugging).never
      end

      it 'does not enable Facter debugging for debug level' do
        Puppet::Util::Log.level = :debug
      end

      it 'does not enable Facter debugging non-debug level' do
        Puppet::Util::Log.level = :info
      end
    end

    describe 'does support debugging' do
      before :each do
        Facter.stubs(:respond_to?).with(:debugging).returns true
      end

      it 'enables Facter debugging when debug level' do
        Facter.stubs(:debugging).with(true)
        Puppet::Util::Log.level = :debug
      end

      it 'disables Facter debugging when not debug level' do
        Facter.stubs(:debugging).with(false)
        Puppet::Util::Log.level = :info
      end
    end

    describe 'does not support trace' do
      before :each do
        Facter.stubs(:respond_to?).with(:trace).returns false
        Facter.stubs(:trace).never
      end

      it 'does not enable Facter trace when enabled' do
        Puppet[:trace] = true
      end

      it 'does not enable Facter trace when disabled' do
        Puppet[:trace] = false
      end
    end

    describe 'does support trace' do
      before :each do
        Facter.stubs(:respond_to?).with(:trace).returns true
      end

      it 'enables Facter trace when enabled' do
        Facter.stubs(:trace).with(true)
        Puppet[:trace] = true
      end

      it 'disables Facter trace when disabled' do
        Facter.stubs(:trace).with(false)
        Puppet[:trace] = false
      end
    end

    describe 'does not support on_message' do
      before :each do
        Facter.stubs(:respond_to?).with(:on_message).returns false
        Facter.stubs(:on_message).never
      end

      it 'does not call Facter.on_message' do
        expect(Puppet::Util::Logging::setup_facter_logging!).to be_falsey
      end
    end

    describe 'does support on_message' do
      before :each do
        Facter.stubs(:respond_to?).with(:on_message).returns true
      end

      def setup(level, message)
        Facter.stubs(:on_message).yields level, message

        # Transform from Facter level to Puppet level
        case level
        when :trace
          level = :debug
        when :warn
          level = :warning
        when :error
          level = :err
        when :fatal
          level = :crit
        end

        Puppet::Util::Log.stubs(:create).with do |options|
          expect(options[:level]).to eq(level)
          expect(options[:message]).to eq(message)
          expect(options[:source]).to eq('Facter')
        end.once
      end

      [:trace, :debug, :info, :warn, :error, :fatal].each do |level|
        it "calls Facter.on_message and handles #{level} messages" do
          setup(level, "#{level} message")
          expect(Puppet::Util::Logging::setup_facter_logging!).to be_truthy
        end
      end
    end
  end
end
