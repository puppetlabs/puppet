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

    describe Puppet::Util::Log::DestConsole do
        before do
            @console = Puppet::Util::Log::DestConsole.new 
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

            @console.colorize(:alert, "abc").should == "<span style=\"color: FFA0A0\">abc</span>"
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

        [:file, :line, :version].each do |attr|
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

        describe "when setting the source as a RAL object" do
            it "should tag itself with any tags the source has" do
                source = Puppet::Type.type(:file).new :path => "/foo/bar"
                log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => source)
                source.tags.each do |tag|
                    log.tags.should be_include(tag)
                end
            end

            it "should use the source_descriptors" do
                source = stub "source"
                source.stubs(:source_descriptors).returns(:tags => ["tag","tag2"], :path => "path", :version => 100)
                
                log = Puppet::Util::Log.new(:level => "notice", :message => :foo)
                log.expects(:tag).with("tag")
                log.expects(:tag).with("tag2")
                log.expects(:version=).with(100)

                log.source = source

                log.source.should == "path"
            end

            it "should copy over any version information" do
                catalog = Puppet::Resource::Catalog.new
                catalog.version = 25
                source = Puppet::Type.type(:file).new :path => "/foo/bar"
                catalog.add_resource source

                log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => source)
                log.version.should == 25
            end

            it "should copy over any file and line information" do
                source = Puppet::Type.type(:file).new :path => "/foo/bar"
                source.file = "/my/file"
                source.line = 50
                log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => source)
                log.file.should == "/my/file"
                log.line.should == 50
            end
        end

        describe "when setting the source as a non-RAL object" do
            it "should not try to copy over file, version, line, or tag information" do
                source = Puppet::Module.new("foo")
                source.expects(:file).never
                log = Puppet::Util::Log.new(:level => "notice", :message => :foo, :source => source)
            end
        end
    end
end
