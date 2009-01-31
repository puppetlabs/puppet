#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/log'

describe Puppet::Util::Log do
    it "should be able to close all log destinations" do
        Puppet::Util::Log.expects(:destinations).returns %w{foo bar}
        Puppet::Util::Log.expects(:close).with("foo")
        Puppet::Util::Log.expects(:close).with("bar")

        Puppet::Util::Log.close_all
    end

    describe "instances" do
        before do
            Puppet::Util::Log.stubs(:newmessage)
        end

        [:level, :message, :time, :remote].each do |attr|
            it "should have a %s attribute" % attr do
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

        it "should use an passed-in source" do
            Puppet::Util::Log.any_instance.expects(:source=).with "foo"
            Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => "foo")
        end

        it "should default to 'Puppet' as its source" do
            Puppet::Util::Log.new(:level => "notice", :message => :foo).source.should == "Puppet"
        end

        it "should register itself with Log" do
            Puppet::Util::Log.expects(:newmessage)
            Puppet::Util::Log.new(:level => "notice", :message => :foo)
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
    end
end
