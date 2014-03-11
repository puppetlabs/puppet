#! /usr/bin/env ruby
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
    message.should == "foo"
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
  end
  describe Puppet::Util::Log::DestConsole do
    before do
      @console = Puppet::Util::Log::DestConsole.new
      @console.stubs(:console_has_color?).returns(true)
    end

    it "should colorize if Puppet[:color] is :ansi" do
      Puppet[:color] = :ansi

      @console.colorize(:alert, "abc").should == "\e[0;31mabc\e[0m"
    end

    it "should colorize if Puppet[:color] is 'yes'" do
      Puppet[:color] = "yes"

      @console.colorize(:alert, "abc").should == "\e[0;31mabc\e[0m"
    end

    it "should htmlize if Puppet[:color] is :html" do
      Puppet[:color] = :html

      @console.colorize(:alert, "abc").should == "<span style=\"color: #FFA0A0\">abc</span>"
    end

    it "should do nothing if Puppet[:color] is false" do
      Puppet[:color] = false

      @console.colorize(:alert, "abc").should == "abc"
    end

    it "should do nothing if Puppet[:color] is invalid" do
      Puppet[:color] = "invalid option"

      @console.colorize(:alert, "abc").should == "abc"
    end
  end

  describe Puppet::Util::Log::DestSyslog do
    before do
      @syslog = Puppet::Util::Log::DestSyslog.new
    end
  end

  describe Puppet::Util::Log::DestEventlog, :if => Puppet.features.eventlog? do
    before :each do
      Win32::EventLog.stubs(:open).returns(mock 'mylog')
      Win32::EventLog.stubs(:report_event)
      Win32::EventLog.stubs(:close)
      Puppet.features.stubs(:eventlog?).returns(true)
    end

    it "should restrict its suitability" do
      Puppet.features.expects(:eventlog?).returns(false)

      Puppet::Util::Log::DestEventlog.suitable?('whatever').should == false
    end

    it "should open the 'Application' event log" do
      Win32::EventLog.expects(:open).with('Application')

      Puppet::Util::Log.newdestination(:eventlog)
    end

    it "should close the event log" do
      log = mock('myeventlog')
      log.expects(:close)
      Win32::EventLog.expects(:open).returns(log)

      Puppet::Util::Log.newdestination(:eventlog)
      Puppet::Util::Log.close(:eventlog)
    end

    it "should handle each puppet log level" do
      log = Puppet::Util::Log::DestEventlog.new

      Puppet::Util::Log.eachlevel do |level|
        log.to_native(level).should be_is_a(Array)
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
        log.should respond_to(attr)
        log.should respond_to(attr.to_s + "=")
      end
    end

    it "should fail if created without a level" do
      lambda { Puppet::Util::Log.new(:message => "A test message") }.should raise_error(ArgumentError)
    end

    it "should fail if created without a message" do
      lambda { Puppet::Util::Log.new(:level => :notice) }.should raise_error(ArgumentError)
    end

    it "should make available the level passed in at initialization" do
      Puppet::Util::Log.new(:level => :notice, :message => "A test message").level.should == :notice
    end

    it "should make available the message passed in at initialization" do
      Puppet::Util::Log.new(:level => :notice, :message => "A test message").message.should == "A test message"
    end

    # LAK:NOTE I don't know why this behavior is here, I'm just testing what's in the code,
    # at least at first.
    it "should always convert messages to strings" do
      Puppet::Util::Log.new(:level => :notice, :message => :foo).message.should == "foo"
    end

    it "should flush the log queue when the first destination is specified" do
      Puppet::Util::Log.close_all
      Puppet::Util::Log.expects(:flushqueue)
      Puppet::Util::Log.newdestination(:console)
    end

    it "should convert the level to a symbol if it's passed in as a string" do
      Puppet::Util::Log.new(:level => "notice", :message => :foo).level.should == :notice
    end

    it "should fail if the level is not a symbol or string" do
      lambda { Puppet::Util::Log.new(:level => 50, :message => :foo) }.should raise_error(ArgumentError)
    end

    it "should fail if the provided level is not valid" do
      Puppet::Util::Log.expects(:validlevel?).with(:notice).returns false
      lambda { Puppet::Util::Log.new(:level => :notice, :message => :foo) }.should raise_error(ArgumentError)
    end

    it "should set its time to the initialization time" do
      time = mock 'time'
      Time.expects(:now).returns time
      Puppet::Util::Log.new(:level => "notice", :message => :foo).time.should equal(time)
    end

    it "should make available any passed-in tags" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :tags => %w{foo bar})
      log.tags.should be_include("foo")
      log.tags.should be_include("bar")
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
      Puppet::Util::Log.new(:level => "notice", :message => :foo).source.should == "Puppet"
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
      Puppet::Util::Log.new(:level => "notice", :message => :foo).should respond_to(:tagged?)
    end

    it "should match a tag if any of the tags are equivalent to the passed tag as a string" do
      Puppet::Util::Log.new(:level => "notice", :message => :foo, :tags => %w{one two}).should be_tagged(:one)
    end

    it "should tag itself with its log level" do
      Puppet::Util::Log.new(:level => "notice", :message => :foo).should be_tagged(:notice)
    end

    it "should return its message when converted to a string" do
      Puppet::Util::Log.new(:level => "notice", :message => :foo).to_s.should == "foo"
    end

    it "should include its time, source, level, and message when prepared for reporting" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo)
      report = log.to_report
      report.should be_include("notice")
      report.should be_include("foo")
      report.should be_include(log.source)
      report.should be_include(log.time.to_s)
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
          log.tags.should be_include(tag)
        end
      end

      it "should set the source to 'path', when available" do
        source = Puppet::Type.type(:file).new :path => path
        source.tags = ["tag", "tag2"]

        log = Puppet::Util::Log.new(:level => "notice", :message => :foo)
        log.expects(:tag).with("file")
        log.expects(:tag).with("tag")
        log.expects(:tag).with("tag2")

        log.source = source

        log.source.should == "/File[#{path}]"
      end

      it "should copy over any file and line information" do
        source = Puppet::Type.type(:file).new :path => path
        source.file = "/my/file"
        source.line = 50
        log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => source)
        log.line.should == 50
        log.file.should == "/my/file"
      end
    end

    describe "when setting the source as a non-RAL object" do
      it "should not try to copy over file, version, line, or tag information" do
        source = mock
        source.expects(:file).never
        log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => source)
      end
    end
  end

  describe "to_yaml" do
    it "should not include the @version attribute" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :version => 100)
      log.to_yaml_properties.should_not include('@version')
    end

    it "should include attributes @level, @message, @source, @tags, and @time" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :version => 100)
      log.to_yaml_properties.should =~ [:@level, :@message, :@source, :@tags, :@time]
    end

    it "should include attributes @file and @line if specified" do
      log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :file => "foo", :line => 35)
      log.to_yaml_properties.should include(:@file)
      log.to_yaml_properties.should include(:@line)
    end
  end

  it "should round trip through pson" do
    log = Puppet::Util::Log.new(:level => 'notice', :message => 'hooray', :file => 'thefile', :line => 1729, :source => 'specs', :tags => ['a', 'b', 'c'])
    tripped = Puppet::Util::Log.from_data_hash(PSON.parse(log.to_pson))

    tripped.file.should == log.file
    tripped.line.should == log.line
    tripped.level.should == log.level
    tripped.message.should == log.message
    tripped.source.should == log.source
    tripped.tags.should == log.tags
    tripped.time.should == log.time
  end
end
