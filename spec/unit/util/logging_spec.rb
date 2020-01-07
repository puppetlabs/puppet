require 'spec_helper'

require 'puppet/util/logging'

Puppet::Type.newtype(:logging_test) do
  newparam(:name, isnamevar: true)
  newproperty(:path)
end
Puppet::Type.type(:logging_test).provide(:logging_test) do
end

class LoggingTester
  include Puppet::Util::Logging
end

class PuppetStackCreator
  def raise_error(exception_class)
    case exception_class
    when Puppet::ParseErrorWithIssue
      raise exception_class.new('Oops', '/tmp/test.pp', 30, 15, nil, :SYNTAX_ERROR)
    when Puppet::ParseError
      raise exception_class.new('Oops', '/tmp/test.pp', 30, 15)
    else
      raise exception_class.new('Oops')
    end
  end

  def call_raiser(exception_class)
    Puppet::Pops::PuppetStack.stack('/tmp/test2.pp', 20, self, :raise_error, [exception_class])
  end

  def two_frames_and_a_raise(exception_class)
    Puppet::Pops::PuppetStack.stack('/tmp/test3.pp', 15, self, :call_raiser, [exception_class])
  end

  def outer_rescue(exception_class)
    begin
      two_frames_and_a_raise(exception_class)
    rescue Puppet::Error => e
      Puppet.log_exception(e)
    end
  end

  def run(exception_class)
    Puppet::Pops::PuppetStack.stack('/tmp/test4.pp', 10, self, :outer_rescue, [exception_class])
  end
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
    expect(@logger).to receive(:to_s).and_return("I'm a string!")
    expect(Puppet::Util::Log).to receive(:create).with(hash_including(source: "I'm a string!", level: "loglevel", message: "mymessage"))

    @logger.send_log "loglevel", "mymessage"
  end

  describe "when sending a log" do
    it "should use the Log's 'create' entrance method" do
      expect(Puppet::Util::Log).to receive(:create)

      @logger.notice "foo"
    end

    it "should send itself converted to a string as the log source" do
      expect(@logger).to receive(:to_s).and_return("I'm a string!")
      expect(Puppet::Util::Log).to receive(:create).with(hash_including(source: "I'm a string!"))

      @logger.notice "foo"
    end

    it "should queue logs sent without a specified destination" do
      Puppet::Util::Log.close_all
      expect(Puppet::Util::Log).to receive(:queuemessage)

      @logger.notice "foo"
    end

    it "should use the path of any provided resource type" do
      resource = Puppet::Type.type(:logging_test).new :name => "foo"

      expect(resource).to receive(:path).and_return("/path/to/host".to_sym)

      expect(Puppet::Util::Log).to receive(:create).with(hash_including(source: "/path/to/host"))

      resource.notice "foo"
    end

    it "should use the path of any provided resource parameter" do
      resource = Puppet::Type.type(:logging_test).new :name => "foo"

      param = resource.parameter(:name)

      expect(param).to receive(:path).and_return("/path/to/param".to_sym)

      expect(Puppet::Util::Log).to receive(:create).with(hash_including(source: "/path/to/param"))

      param.notice "foo"
    end

    it "should send the provided argument as the log message" do
      expect(Puppet::Util::Log).to receive(:create).with(hash_including(message: "foo"))

      @logger.notice "foo"
    end

    it "should join any provided arguments into a single string for the message" do
      expect(Puppet::Util::Log).to receive(:create).with(hash_including(message: "foo bar baz"))

      @logger.notice ["foo", "bar", "baz"]
    end

    [:file, :line, :tags].each do |attr|
      it "should include #{attr} if available" do
        @logger.singleton_class.send(:attr_accessor, attr)

        @logger.send(attr.to_s + "=", "myval")

        expect(Puppet::Util::Log).to receive(:create).with(hash_including(attr => "myval"))
        @logger.notice "foo"
      end
    end
  end

  describe "log_exception" do
    context "when requesting a debug level it is logged at debug" do
      it "the exception is a ParseErrorWithIssue and message is :default" do
        expect(Puppet::Util::Log).to receive(:create) do |args|
          expect(args[:message]).to eq("Test")
          expect(args[:level]).to eq(:debug)
        end

        begin
          raise Puppet::ParseErrorWithIssue, "Test"
        rescue Puppet::ParseErrorWithIssue => err
          Puppet.log_exception(err, :default, level: :debug)
        end
      end

      it "the exception is something else" do
        expect(Puppet::Util::Log).to receive(:create) do |args|
          expect(args[:message]).to eq("Test")
          expect(args[:level]).to eq(:debug)
        end

        begin
          raise Puppet::Error, "Test"
        rescue Puppet::Error => err
          Puppet.log_exception(err, :default, level: :debug)
        end
      end
    end

    context "no log level is requested it defaults to err" do
      it "the exception is a ParseErrorWithIssue and message is :default" do
        expect(Puppet::Util::Log).to receive(:create) do |args|
          expect(args[:message]).to eq("Test")
          expect(args[:level]).to eq(:err)
        end

        begin
          raise Puppet::ParseErrorWithIssue, "Test"
        rescue Puppet::ParseErrorWithIssue => err
          Puppet.log_exception(err)
        end
      end

      it "the exception is something else" do
        expect(Puppet::Util::Log).to receive(:create) do |args|
          expect(args[:message]).to eq("Test")
          expect(args[:level]).to eq(:err)
        end

        begin
          raise Puppet::Error, "Test"
        rescue Puppet::Error => err
          Puppet.log_exception(err)
        end
      end
    end
  end

  describe "when sending a deprecation warning" do
    it "does not log a message when deprecation warnings are disabled" do
      expect(Puppet).to receive(:[]).with(:disable_warnings).and_return(%w[deprecations])
      expect(@logger).not_to receive(:warning)
      @logger.deprecation_warning 'foo'
    end

    it "logs the message with warn" do
      expect(@logger).to receive(:warning).with(/^foo\n/)
      @logger.deprecation_warning 'foo'
    end

    it "only logs each offending line once" do
      expect(@logger).to receive(:warning).with(/^foo\n/).once
      5.times { @logger.deprecation_warning 'foo' }
    end

    it "ensures that deprecations from same origin are logged if their keys differ" do
      expect(@logger).to receive(:warning).with(/deprecated foo/).exactly(5).times()
      5.times { |i| @logger.deprecation_warning('deprecated foo', :key => "foo#{i}") }
    end

    it "does not duplicate deprecations for a given key" do
      expect(@logger).to receive(:warning).with(/deprecated foo/).once
      5.times { @logger.deprecation_warning('deprecated foo', :key => 'foo-msg') }
    end

    it "only logs the first 100 messages" do
      (1..100).each { |i|
        expect(@logger).to receive(:warning).with(/^#{i}\n/).once
        # since the deprecation warning will only log each offending line once, we have to do some tomfoolery
        # here in order to make it think each of these calls is coming from a unique call stack; we're basically
        # mocking the method that it would normally use to find the call stack.
        expect(@logger).to receive(:get_deprecation_offender).and_return(["deprecation log count test ##{i}"])
        @logger.deprecation_warning i
      }
      expect(@logger).not_to receive(:warning).with(101)
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
      expect(@logger).to receive(:warning).with(/deprecated foo.*\(file: afile, line: 5\)/m)
      @logger.puppet_deprecation_warning("deprecated foo", :file => 'afile', :line => 5)
    end

    it "warns keyed from file and line" do
      expect(@logger).to receive(:warning).with(/deprecated foo.*\(file: afile, line: 5\)/m).once
      5.times do
        @logger.puppet_deprecation_warning("deprecated foo", :file => 'afile', :line => 5)
      end
    end

    it "warns with separate key only once regardless of file and line" do
      expect(@logger).to receive(:warning).with(/deprecated foo.*\(file: afile, line: 5\)/m).once
      @logger.puppet_deprecation_warning("deprecated foo", :key => 'some_key', :file => 'afile', :line => 5)
      @logger.puppet_deprecation_warning("deprecated foo", :key => 'some_key', :file => 'bfile', :line => 3)
    end

    it "warns with key but no file and line" do
      expect(@logger).to receive(:warning).with(/deprecated foo.*\(file: unknown, line: unknown\)/m)
      @logger.puppet_deprecation_warning("deprecated foo", :key => 'some_key')
    end
  end

  describe "when sending a warn_once" do
    before(:each) {
      @logger.clear_deprecation_warnings
    }

    it "warns with file when only file is given" do
      expect(@logger).to receive(:send_log).with(:warning, /wet paint.*\(file: aFile\)/m)
      @logger.warn_once('kind', 'wp', "wet paint", 'aFile')
    end

    it "warns with unknown file and line when only line is given" do
      expect(@logger).to receive(:send_log).with(:warning, /wet paint.*\(line: 5\)/m)
      @logger.warn_once('kind', 'wp', "wet paint", nil, 5)
    end

    it "warns with file and line when both are given" do
      expect(@logger).to receive(:send_log).with(:warning, /wet paint.*\(file: aFile, line: 5\)/m)
      @logger.warn_once('kind', 'wp', "wet paint",'aFile', 5)
    end

    it "warns once per key" do
      expect(@logger).to receive(:send_log).with(:warning, /wet paint.*/m).once
      5.times do
        @logger.warn_once('kind', 'wp', "wet paint")
      end
    end

    Puppet::Util::Log.eachlevel do |level|
      it "can use log level #{level}" do
        expect(@logger).to receive(:send_log).with(level, /wet paint.*/m).once
        5.times do
          @logger.warn_once('kind', 'wp', "wet paint", nil, nil, level)
        end
      end
    end
  end

  describe "does not warn about undefined variables when disabled_warnings says so" do
    let(:logger) { LoggingTester.new }

    before(:each) do
      Puppet.settings.initialize_global_settings
      logger.clear_deprecation_warnings
      Puppet[:disable_warnings] = ['undefined_variables']
    end

    after(:each) do
      Puppet[:disable_warnings] = []
      allow(logger).to receive(:send_log).and_call_original()
      allow(Facter).to receive(:respond_to?).and_call_original()
      allow(Facter).to receive(:debugging).and_call_original()
    end

    it "does not produce warning if kind is disabled" do
      expect(logger).not_to receive(:send_log)
      logger.warn_once('undefined_variables', 'wp', "wet paint")
    end
  end

  describe "warns about undefined variables when deprecations are in disabled_warnings" do
    let(:logger) { LoggingTester.new }

    before(:each) do
      Puppet.settings.initialize_global_settings
      logger.clear_deprecation_warnings
      Puppet[:disable_warnings] = ['deprecations']
    end

    after(:each) do
      Puppet[:disable_warnings] = []
      allow(logger).to receive(:send_log).and_call_original()
      allow(Facter).to receive(:respond_to?).and_call_original()
      allow(Facter).to receive(:debugging).and_call_original()
    end

    it "produces warning even if deprecation warnings are disabled " do
      expect(logger).to receive(:send_log).with(:warning, /wet paint/).once
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

    describe "when trace is disabled" do
      it 'excludes backtrace for RuntimeError in log message' do
        begin
          raise RuntimeError, 'Oops'
        rescue RuntimeError => e
          Puppet.log_exception(e)
        end

        expect(@logs.size).to eq(1)
        log = @logs[0]
        expect(log.message).to_not match('/logging_spec.rb')
        expect(log.backtrace).to be_nil
      end

      it "backtrace member is unset when logging ParseErrorWithIssue" do
        begin
          raise Puppet::ParseErrorWithIssue.new('Oops', '/tmp/test.pp', 30, 15, nil, :SYNTAX_ERROR)
        rescue RuntimeError => e
          Puppet.log_exception(e)
        end

        expect(@logs.size).to eq(1)
        log = @logs[0]
        expect(log.message).to_not match('/logging_spec.rb')
        expect(log.backtrace).to be_nil
      end
    end

    describe "when trace is enabled" do
      it 'includes backtrace for RuntimeError in log message when enabled globally' do
        Puppet[:trace] = true
        begin
          raise RuntimeError, 'Oops'
        rescue RuntimeError => e
          Puppet.log_exception(e, :default)
        end
        Puppet[:trace] = false

        expect(@logs.size).to eq(1)
        log = @logs[0]
        expect(log.message).to match('/logging_spec.rb')
        expect(log.backtrace).to be_nil
      end

      it 'includes backtrace for RuntimeError in log message when enabled via option' do
        begin
          raise RuntimeError, 'Oops'
        rescue RuntimeError => e
          Puppet.log_exception(e, :default, :trace => true)
        end

        expect(@logs.size).to eq(1)
        log = @logs[0]
        expect(log.message).to match('/logging_spec.rb')
        expect(log.backtrace).to be_nil
      end


      it "backtrace member is set when logging ParseErrorWithIssue" do
        begin
          raise Puppet::ParseErrorWithIssue.new('Oops', '/tmp/test.pp', 30, 15, nil, :SYNTAX_ERROR)
        rescue RuntimeError => e
          Puppet.log_exception(e, :default, :trace => true)
        end

        expect(@logs.size).to eq(1)
        log = @logs[0]
        expect(log.message).to_not match('/logging_spec.rb')
        expect(log.backtrace).to be_a(Array)
        expect(log.backtrace[0]).to match('/logging_spec.rb')
      end
      it "backtrace has interleaved PuppetStack when logging ParseErrorWithIssue" do
        Puppet[:trace] = true
        PuppetStackCreator.new.run(Puppet::ParseErrorWithIssue)
        Puppet[:trace] = false

        expect(@logs.size).to eq(1)
        log = @logs[0]
        expect(log.message).to_not match('/logging_spec.rb')
        expect(log.backtrace[0]).to match('/logging_spec.rb')

        expect(log.backtrace[1]).to match('/tmp/test2.pp:20')
        puppetstack = log.backtrace.select { |l| l =~ /tmp\/test\d\.pp/ }

        expect(puppetstack.length).to equal 3
      end

      it "message has interleaved PuppetStack when logging ParseError" do
        Puppet[:trace] = true
        PuppetStackCreator.new.run(Puppet::ParseError)
        Puppet[:trace] = false

        expect(@logs.size).to eq(1)
        log = @logs[0]

        log_lines = log.message.split("\n")
        expect(log_lines[1]).to match('/logging_spec.rb')
        expect(log_lines[2]).to match('/tmp/test2.pp:20')
        puppetstack = log_lines.select { |l| l =~ /tmp\/test\d\.pp/ }

        expect(puppetstack.length).to equal 3
      end
    end

    describe "when trace is disabled but puppet_trace is enabled" do
      it "includes only PuppetStack as backtrace member with ParseErrorWithIssue" do
        Puppet[:trace] = false
        Puppet[:puppet_trace] = true
        PuppetStackCreator.new.run(Puppet::ParseErrorWithIssue)
        Puppet[:trace] = false
        Puppet[:puppet_trace] = false

        expect(@logs.size).to eq(1)
        log = @logs[0]

        expect(log.backtrace[0]).to match('/tmp/test2.pp:20')
        expect(log.backtrace.length).to equal 3
      end

      it "includes only PuppetStack in message with ParseError" do
        Puppet[:trace] = false
        Puppet[:puppet_trace] = true
        PuppetStackCreator.new.run(Puppet::ParseError)
        Puppet[:trace] = false
        Puppet[:puppet_trace] = false

        expect(@logs.size).to eq(1)
        log = @logs[0]

        log_lines = log.message.split("\n")
        expect(log_lines[1]).to match('/tmp/test2.pp:20')
        puppetstack = log_lines.select { |l| l =~ /tmp\/test\d\.pp/ }

        expect(puppetstack.length).to equal 3
      end
    end

    it 'includes position details for ParseError in log message' do
      begin
        raise Puppet::ParseError.new('Oops', '/tmp/test.pp', 30, 15)
      rescue RuntimeError => e
        Puppet.log_exception(e)
      end

      expect(@logs.size).to eq(1)
      log = @logs[0]
      expect(log.message).to match(/ \(file: \/tmp\/test\.pp, line: 30, column: 15\)/)
      expect(log.message).to be(log.to_s)
    end

    it 'excludes position details for ParseErrorWithIssue from log message' do
      begin
        raise Puppet::ParseErrorWithIssue.new('Oops', '/tmp/test.pp', 30, 15, nil, :SYNTAX_ERROR)
      rescue RuntimeError => e
        Puppet.log_exception(e)
      end

      expect(@logs.size).to eq(1)
      log = @logs[0]
      expect(log.message).to_not match(/ \(file: \/tmp\/test\.pp, line: 30, column: 15\)/)
      expect(log.to_s).to match(/ \(file: \/tmp\/test\.pp, line: 30, column: 15\)/)
      expect(log.issue_code).to eq(:SYNTAX_ERROR)
      expect(log.file).to eq('/tmp/test.pp')
      expect(log.line).to eq(30)
      expect(log.pos).to eq(15)
    end
  end

  describe 'when Facter' do
    after :each do
      # Unstub these calls as there is global code run after
      # each spec that may reset the log level to debug
      allow(Facter).to receive(:respond_to?).and_call_original()
      allow(Facter).to receive(:debugging).and_call_original()
    end

    describe 'does support debugging' do
      before :each do
        allow(Facter).to receive(:respond_to?).with(:debugging).and_return(true)
      end

      it 'enables Facter debugging when debug level' do
        allow(Facter).to receive(:debugging).with(true)
        Puppet::Util::Log.level = :debug
      end

      it 'disables Facter debugging when not debug level' do
        allow(Facter).to receive(:debugging).with(false)
        Puppet::Util::Log.level = :info
      end
    end

    describe 'does support trace' do
      before :each do
        allow(Facter).to receive(:respond_to?).with(:trace).and_return(true)
      end

      it 'enables Facter trace when enabled' do
        allow(Facter).to receive(:trace).with(true)
        Puppet[:trace] = true
      end

      it 'disables Facter trace when disabled' do
        allow(Facter).to receive(:trace).with(false)
        Puppet[:trace] = false
      end
    end

    describe 'does support on_message' do
      before :each do
        allow(Facter).to receive(:respond_to?).with(:on_message).and_return(true)
      end

      def setup(level, message)
        allow(Facter).to receive(:on_message).and_yield(level, message)

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

        allow(Puppet::Util::Log).to receive(:create).with(hash_including(level: level, message: message, source: 'Facter')).once
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
