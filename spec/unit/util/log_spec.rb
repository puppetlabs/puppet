#! /usr/bin/env ruby
# coding: utf-8
require 'spec_helper'

require 'puppet/util/log'

describe Puppet::Util::Log do
  include PuppetSpec::Files

  def log_notice(message)
    Puppet::Util::Log.new(:level => :notice, :message => message)
  end

  it "should write a given message to the specified destination" do
    arraydest = []
    Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(arraydest))
    Puppet::Util::Log.new(:level => :notice, :message => "foo")
    message = arraydest.last.message
    expect(message).to eq("foo")
  end

  context "given a message with invalid encoding" do
    let(:logs) { [] }
    let(:invalid_message) { "\xFD\xFBfoo".force_encoding(Encoding::Shift_JIS) }

    before do
      Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(logs))
      Puppet::Util::Log.new(:level => :notice, :message => invalid_message)
    end

    it "does not raise an error" do
      expect { Puppet::Util::Log.new(:level => :notice, :message => invalid_message) }.not_to raise_error
    end

    it "includes a backtrace in the log" do
      expect(logs.last.message).to match(/Backtrace:\n.*in `newmessage'\n.*in `initialize'/ )
    end

    it "warns that message included invalid encoding" do
      expect(logs.last.message).to match(/Received a Log attribute with invalid encoding/)
    end

    it "includes the 'dump' of the invalid message" do
      expect(logs.last.message).to match(/\"\\xFD\\xFBfoo\"/)
    end
  end

  # need a string that cannot be converted to US-ASCII or other encodings easily
  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte ܎ - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ܎

  it "converts a given non-UTF-8 message to UTF-8" do
    logs = []
    Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(logs))
    Puppet::Util::Log.newdestination(:console)

    # HIRAGANA LETTER SO
    # In Windows_31J: \x82 \xbb - 130 187
    # In Unicode: \u305d - \xe3 \x81 \x9d - 227 129 157
    win_31j_msg = [130, 187].pack('C*').force_encoding(Encoding::Windows_31J)
    utf_8_msg = "\u305d"

    $stdout.expects(:puts).with("\e[mNotice: #{mixed_utf8}: #{utf_8_msg}\e[0m")

    # most handlers do special things with a :source => 'Puppet', so use something else
    Puppet::Util::Log.new(:level => :notice, :message => win_31j_msg, :source => mixed_utf8)
    expect(logs.last.message).to eq(utf_8_msg)
  end

  it "converts a given non-UTF-8 source to UTF-8" do
    logs = []
    Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(logs))
    Puppet::Util::Log.newdestination(:console)

    # HIRAGANA LETTER SO
    # In Windows_31J: \x82 \xbb - 130 187
    # In Unicode: \u305d - \xe3 \x81 \x9d - 227 129 157
    win_31j_msg = [130, 187].pack('C*').force_encoding(Encoding::Windows_31J)
    utf_8_msg = "\u305d"

    $stdout.expects(:puts).with("\e[mNotice: #{utf_8_msg}: #{mixed_utf8}\e[0m")

    Puppet::Util::Log.new(:level => :notice, :message => mixed_utf8, :source => win_31j_msg)
    expect(logs.last.source).to eq(utf_8_msg)
  end

  describe ".setup_default" do
    it "should default to :syslog" do
      Puppet.features.stubs(:syslog?).returns(true)
      Puppet::Util::Log.expects(:newdestination).with(:syslog)

      Puppet::Util::Log.setup_default
    end

    it "should fall back to :eventlog" do
      Puppet.features.stubs(:syslog?).returns(false)
      Puppet.features.stubs(:eventlog?).returns(true)
      Puppet::Util::Log.expects(:newdestination).with(:eventlog)

      Puppet::Util::Log.setup_default
    end

    it "should fall back to :file" do
      Puppet.features.stubs(:syslog?).returns(false)
      Puppet.features.stubs(:eventlog?).returns(false)
      Puppet::Util::Log.expects(:newdestination).with(Puppet[:puppetdlog])

      Puppet::Util::Log.setup_default
    end
  end

  describe "#with_destination" do
    it "does nothing when nested" do
      logs = []
      destination = Puppet::Test::LogCollector.new(logs)
      Puppet::Util::Log.with_destination(destination) do
        Puppet::Util::Log.with_destination(destination) do
          log_notice("Inner block")
        end

        log_notice("Outer block")
      end

      log_notice("Outside")

      expect(logs.collect(&:message)).to include("Inner block", "Outer block")
      expect(logs.collect(&:message)).not_to include("Outside")
    end

    it "logs when called a second time" do
      logs = []
      destination = Puppet::Test::LogCollector.new(logs)

      Puppet::Util::Log.with_destination(destination) do
        log_notice("First block")
      end

      log_notice("Between blocks")

      Puppet::Util::Log.with_destination(destination) do
        log_notice("Second block")
      end

      expect(logs.collect(&:message)).to include("First block", "Second block")
      expect(logs.collect(&:message)).not_to include("Between blocks")
    end

    it "doesn't close the destination if already set manually" do
      logs = []
      destination = Puppet::Test::LogCollector.new(logs)

      Puppet::Util::Log.newdestination(destination)
      Puppet::Util::Log.with_destination(destination) do
        log_notice "Inner block"
      end

      log_notice "Outer block"
      Puppet::Util::Log.close(destination)

      expect(logs.collect(&:message)).to include("Inner block", "Outer block")
    end

    it 'includes backtrace for RuntimeError in log message when trace is enabled' do
      logs = []
      destination = Puppet::Test::LogCollector.new(logs)

      Puppet::Util::Log.newdestination(destination)
      Puppet::Util::Log.with_destination(destination) do
        begin
          raise RuntimeError, 'Oops'
        rescue RuntimeError => e
          Puppet.log_exception(e, :default, :trace => true)
        end
      end
      expect(logs.size).to eq(1)
      log = logs[0]
      expect(log.message).to match('/log_spec.rb')
      expect(log.backtrace).to be_nil
    end

    it 'excludes backtrace for RuntimeError in log message when trace is disabled' do
      logs = []
      destination = Puppet::Test::LogCollector.new(logs)

      Puppet::Util::Log.newdestination(destination)
      Puppet::Util::Log.with_destination(destination) do
        begin
          raise RuntimeError, 'Oops'
        rescue RuntimeError => e
          Puppet.log_exception(e)
        end
      end
      expect(logs.size).to eq(1)
      log = logs[0]
      expect(log.message).to_not match('/log_spec.rb')
      expect(log.backtrace).to be_nil
    end

    it "backtrace is Array in 'backtrace' and excluded from 'message' when logging ParseErrorWithIssue with trace enabled" do
      logs = []
      destination = Puppet::Test::LogCollector.new(logs)

      Puppet::Util::Log.newdestination(destination)
      Puppet::Util::Log.with_destination(destination) do
        begin
          raise Puppet::ParseErrorWithIssue.new('Oops', '/tmp/test.pp', 30, 15, nil, :SYNTAX_ERROR)
        rescue RuntimeError => e
          Puppet.log_exception(e, :default, :trace => true)
        end
      end
      expect(logs.size).to eq(1)
      log = logs[0]
      expect(log.message).to_not match('/log_spec.rb')
      expect(log.backtrace).to be_a(Array)
    end

    it "backtrace is excluded when logging ParseErrorWithIssue with trace disabled" do
      logs = []
      destination = Puppet::Test::LogCollector.new(logs)

      Puppet::Util::Log.newdestination(destination)
      Puppet::Util::Log.with_destination(destination) do
        begin
          raise Puppet::ParseErrorWithIssue.new('Oops', '/tmp/test.pp', 30, 15, nil, :SYNTAX_ERROR)
        rescue RuntimeError => e
          Puppet.log_exception(e)
        end
      end
      expect(logs.size).to eq(1)
      log = logs[0]
      expect(log.message).to_not match('/log_spec.rb')
      expect(log.backtrace).to be_nil
    end

    it 'includes position details for ParseError in log message' do
      logs = []
      destination = Puppet::Test::LogCollector.new(logs)

      Puppet::Util::Log.newdestination(destination)
      Puppet::Util::Log.with_destination(destination) do
        begin
          raise Puppet::ParseError.new('Oops', '/tmp/test.pp', 30, 15)
        rescue RuntimeError => e
          Puppet.log_exception(e)
        end
      end
      expect(logs.size).to eq(1)
      log = logs[0]
      expect(log.message).to match(/ \(file: \/tmp\/test\.pp, line: 30, column: 15\)/)
      expect(log.message).to be(log.to_s)
    end

    it 'excludes position details for ParseErrorWithIssue from log message' do
      logs = []
      destination = Puppet::Test::LogCollector.new(logs)

      Puppet::Util::Log.newdestination(destination)
      Puppet::Util::Log.with_destination(destination) do
        begin
          raise Puppet::ParseErrorWithIssue.new('Oops', '/tmp/test.pp', 30, 15, nil, :SYNTAX_ERROR)
        rescue RuntimeError => e
          Puppet.log_exception(e)
        end
      end
      expect(logs.size).to eq(1)
      log = logs[0]
      expect(log.message).to_not match(/ \(file: \/tmp\/test\.pp, line: 30, column: 15\)/)
      expect(log.to_s).to match(/ \(file: \/tmp\/test\.pp, line: 30, column: 15\)/)
      expect(log.issue_code).to eq(:SYNTAX_ERROR)
      expect(log.file).to eq('/tmp/test.pp')
      expect(log.line).to eq(30)
      expect(log.pos).to eq(15)
    end
  end

  describe Puppet::Util::Log::DestConsole do
    before do
      @console = Puppet::Util::Log::DestConsole.new
    end

    it "should colorize if Puppet[:color] is :ansi" do
      Puppet[:color] = :ansi

      expect(@console.colorize(:alert, "abc")).to eq("\e[0;31mabc\e[0m")
    end

    it "should colorize if Puppet[:color] is 'yes'" do
      Puppet[:color] = "yes"

      expect(@console.colorize(:alert, "abc")).to eq("\e[0;31mabc\e[0m")
    end

    it "should htmlize if Puppet[:color] is :html" do
      Puppet[:color] = :html

      expect(@console.colorize(:alert, "abc")).to eq("<span style=\"color: #FFA0A0\">abc</span>")
    end

    it "should do nothing if Puppet[:color] is false" do
      Puppet[:color] = false

      expect(@console.colorize(:alert, "abc")).to eq("abc")
    end

    it "should do nothing if Puppet[:color] is invalid" do
      Puppet[:color] = "invalid option"

      expect(@console.colorize(:alert, "abc")).to eq("abc")
    end
  end

  describe Puppet::Util::Log::DestSyslog do
    before do
      @syslog = Puppet::Util::Log::DestSyslog.new
    end
  end

  describe Puppet::Util::Log::DestEventlog, :if => Puppet.features.eventlog? do
    before :each do
      Puppet::Util::Windows::EventLog.stubs(:open).returns(stub 'mylog')
      Puppet::Util::Windows::EventLog.stubs(:report_event)
      Puppet::Util::Windows::EventLog.stubs(:close)
      Puppet.features.stubs(:eventlog?).returns(true)
    end

    it "should restrict its suitability to Windows" do
      Puppet.features.expects(:microsoft_windows?).returns(false)

      expect(Puppet::Util::Log::DestEventlog.suitable?('whatever')).to eq(false)
    end

    it "should open the 'Puppet' event log" do
      Puppet::Util::Windows::EventLog.expects(:open).with('Puppet')

      Puppet::Util::Log.newdestination(:eventlog)
    end

    it "should close the event log" do
      log = stub('myeventlog')
      log.expects(:close)
      Puppet::Util::Windows::EventLog.expects(:open).returns(log)

      Puppet::Util::Log.newdestination(:eventlog)
      Puppet::Util::Log.close(:eventlog)
    end

    it "should handle each puppet log level" do
      log = Puppet::Util::Log::DestEventlog.new

      Puppet::Util::Log.eachlevel do |level|
        expect(log.to_native(level)).to be_is_a(Array)
      end
    end
  end

  describe "instances" do
    before do
      Puppet::Util::Log.stubs(:newmessage)
    end

    [:level, :message, :time, :remote].each do |attr|
      it "should have a #{attr} attribute" do
        log = Puppet::Util::Log.new :level => :notice, :message => "A test message"
        expect(log).to respond_to(attr)
        expect(log).to respond_to(attr.to_s + "=")
      end
    end

    it "should fail if created without a level" do
      expect { Puppet::Util::Log.new(:message => "A test message") }.to raise_error(ArgumentError)
    end

    it "should fail if created without a message" do
      expect { Puppet::Util::Log.new(:level => :notice) }.to raise_error(ArgumentError)
    end

    it "should make available the level passed in at initialization" do
      expect(Puppet::Util::Log.new(:level => :notice, :message => "A test message").level).to eq(:notice)
    end

    it "should make available the message passed in at initialization" do
      expect(Puppet::Util::Log.new(:level => :notice, :message => "A test message").message).to eq("A test message")
    end

    # LAK:NOTE I don't know why this behavior is here, I'm just testing what's in the code,
    # at least at first.
    it "should always convert messages to strings" do
      expect(Puppet::Util::Log.new(:level => :notice, :message => :foo).message).to eq("foo")
    end

    it "should flush the log queue when the first destination is specified" do
      Puppet::Util::Log.close_all
      Puppet::Util::Log.expects(:flushqueue)
      Puppet::Util::Log.newdestination(:console)
    end

    it "should convert the level to a symbol if it's passed in as a string" do
      expect(Puppet::Util::Log.new(:level => "notice", :message => :foo).level).to eq(:notice)
    end

    it "should fail if the level is not a symbol or string" do
      expect { Puppet::Util::Log.new(:level => 50, :message => :foo) }.to raise_error(ArgumentError)
    end

    it "should fail if the provided level is not valid" do
      Puppet::Util::Log.expects(:validlevel?).with(:notice).returns false
      expect { Puppet::Util::Log.new(:level => :notice, :message => :foo) }.to raise_error(ArgumentError)
    end

    it "should set its time to the initialization time" do
      time = mock 'time'
      Time.expects(:now).returns time
      expect(Puppet::Util::Log.new(:level => "notice", :message => :foo).time).to equal(time)
    end

    it "should make available any passed-in tags" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :tags => %w{foo bar})
      expect(log.tags).to be_include("foo")
      expect(log.tags).to be_include("bar")
    end

    it "should use a passed-in source" do
      Puppet::Util::Log.any_instance.expects(:source=).with "foo"
      Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => "foo")
    end

    [:file, :line].each do |attr|
      it "should use #{attr} if provided" do
        Puppet::Util::Log.any_instance.expects(attr.to_s + "=").with "foo"
        Puppet::Util::Log.new(:level => "notice", :message => :foo, attr => "foo")
      end
    end

    it "should default to 'Puppet' as its source" do
      expect(Puppet::Util::Log.new(:level => "notice", :message => :foo).source).to eq("Puppet")
    end

    it "should register itself with Log" do
      Puppet::Util::Log.expects(:newmessage)
      Puppet::Util::Log.new(:level => "notice", :message => :foo)
    end

    it "should update Log autoflush when Puppet[:autoflush] is set" do
      Puppet::Util::Log.expects(:autoflush=).once.with(true)
      Puppet[:autoflush] = true
    end

    it "should have a method for determining if a tag is present" do
      expect(Puppet::Util::Log.new(:level => "notice", :message => :foo)).to respond_to(:tagged?)
    end

    it "should match a tag if any of the tags are equivalent to the passed tag as a string" do
      expect(Puppet::Util::Log.new(:level => "notice", :message => :foo, :tags => %w{one two})).to be_tagged(:one)
    end

    it "should tag itself with its log level" do
      expect(Puppet::Util::Log.new(:level => "notice", :message => :foo)).to be_tagged(:notice)
    end

    it "should return its message when converted to a string" do
      expect(Puppet::Util::Log.new(:level => "notice", :message => :foo).to_s).to eq("foo")
    end

    it "should include its time, source, level, and message when prepared for reporting" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo)
      report = log.to_report
      expect(report).to be_include("notice")
      expect(report).to be_include("foo")
      expect(report).to be_include(log.source)
      expect(report).to be_include(log.time.to_s)
    end

    it "should not create unsuitable log destinations" do
      Puppet.features.stubs(:syslog?).returns(false)

      Puppet::Util::Log::DestSyslog.expects(:suitable?)
      Puppet::Util::Log::DestSyslog.expects(:new).never

      Puppet::Util::Log.newdestination(:syslog)
    end

    describe "when setting the source as a RAL object" do
      let(:path) { File.expand_path('/foo/bar') }

      it "should tag itself with any tags the source has" do
        source = Puppet::Type.type(:file).new :path => path
        log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => source)
        source.tags.each do |tag|
          expect(log.tags).to be_include(tag)
        end
      end

      it "should set the source to a type's 'path', when available" do
        source = Puppet::Type.type(:file).new :path => path
        source.tags = ["tag", "tag2"]

        log = Puppet::Util::Log.new(:level => "notice", :message => :foo)
        log.source = source

        expect(log).to be_tagged('file')
        expect(log).to be_tagged('tag')
        expect(log).to be_tagged('tag2')

        expect(log.source).to eq("/File[#{path}]")
      end

      it "should set the source to a provider's type's 'path', when available" do
        source = Puppet::Type.type(:file).new :path => path
        source.tags = ["tag", "tag2"]

        log = Puppet::Util::Log.new(:level => "notice", :message => :foo)

        log.source = source.provider

        expect(log.source).to match Regexp.quote("File\[#{path}\]\(provider=")
      end

      it "should copy over any file and line information" do
        source = Puppet::Type.type(:file).new :path => path
        source.file = "/my/file"
        source.line = 50
        log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => source)
        expect(log.line).to eq(50)
        expect(log.file).to eq("/my/file")
      end
    end

    describe "when setting the source as a non-RAL object" do
      it "should not try to copy over file, version, line, or tag information" do
        source = mock
        source.expects(:file).never
        Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => source)
      end
    end
  end

  describe "to_yaml" do
    it "should not include the @version attribute" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :version => 100)
      expect(log.to_data_hash.keys).not_to include('version')
    end

    it "should include attributes 'file', 'line', 'level', 'message', 'source', 'tags', and 'time'" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :version => 100)
      expect(log.to_data_hash.keys).to match_array(%w(file line level message source tags time))
    end

    it "should include attributes 'file' and 'line' if specified" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :file => "foo", :line => 35)
      expect(log.to_data_hash.keys).to include('file')
      expect(log.to_data_hash.keys).to include('line')
    end
  end

  let(:log) { Puppet::Util::Log.new(:level => 'notice', :message => 'hooray', :file => 'thefile', :line => 1729, :source => 'specs', :tags => ['a', 'b', 'c']) }

  it "should round trip through json" do
    tripped = Puppet::Util::Log.from_data_hash(JSON.parse(log.to_json))

    expect(tripped.file).to eq(log.file)
    expect(tripped.line).to eq(log.line)
    expect(tripped.level).to eq(log.level)
    expect(tripped.message).to eq(log.message)
    expect(tripped.source).to eq(log.source)
    expect(tripped.tags).to eq(log.tags)
    expect(tripped.time).to eq(log.time)
  end

  it 'to_data_hash returns value that is instance of to Data' do
    expect(Puppet::Pops::Types::TypeFactory.data.instance?(log.to_data_hash)).to be_truthy
  end
end
