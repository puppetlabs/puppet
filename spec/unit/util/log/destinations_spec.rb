#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/log'

describe Puppet::Util::Log.desttypes[:report] do
  before do
    @dest = Puppet::Util::Log.desttypes[:report]
  end

  it "should require a report at initialization" do
    @dest.new("foo").report.should == "foo"
  end

  it "should send new messages to the report" do
    report = mock 'report'
    dest = @dest.new(report)

    report.expects(:<<).with("my log")

    dest.handle "my log"
  end
end


describe Puppet::Util::Log.desttypes[:file] do
  before do
    File.stubs(:open)           # prevent actually creating the file
    @class = Puppet::Util::Log.desttypes[:file]
  end

  it "should default to autoflush false" do
    @class.new('/tmp/log').autoflush.should == false
  end

  describe "when matching" do
    shared_examples_for "file destination" do
      it "should match an absolute path" do
        @class.match?(abspath).should be_true
      end

      it "should not match a relative path" do
        @class.match?(relpath).should be_false
      end
    end

    describe "on POSIX systems" do
      before :each do Puppet.features.stubs(:microsoft_windows?).returns false end

      let (:abspath) { '/tmp/log' }
      let (:relpath) { 'log' }

      it_behaves_like "file destination"
    end

    describe "on Windows systems" do
      before :each do Puppet.features.stubs(:microsoft_windows?).returns true end

      let (:abspath) { 'C:\\temp\\log.txt' }
      let (:relpath) { 'log.txt' }

      it_behaves_like "file destination"
    end
  end
end

describe Puppet::Util::Log.desttypes[:syslog] do
  let (:klass) { Puppet::Util::Log.desttypes[:syslog] }

  # these tests can only be run when syslog is present, because
  # we can't stub the top-level Syslog module
  describe "when syslog is available", :if => Puppet.features.syslog? do
    before :each do
      Syslog.stubs(:opened?).returns(false)
      Syslog.stubs(:const_get).returns("LOG_KERN").returns(0)
      Syslog.stubs(:open)
    end

    it "should open syslog" do
      Syslog.expects(:open)

      klass.new
    end

    it "should close syslog" do
      Syslog.expects(:close)

      dest = klass.new
      dest.close
    end

    it "should send messages to syslog" do
      syslog = mock 'syslog'
      syslog.expects(:info).with("don't panic")
      Syslog.stubs(:open).returns(syslog)

      msg = Puppet::Util::Log.new(:level => :info, :message => "don't panic")
      dest = klass.new
      dest.handle(msg)
    end
  end

  describe "when syslog is unavailable" do
    it "should not be a suitable log destination" do
      Puppet.features.stubs(:syslog?).returns(false)

      klass.suitable?(:syslog).should be_false
    end
  end
end

describe Puppet::Util::Log.desttypes[:console] do
  describe "when color is available" do
    it "should support color output" do
      Puppet.stubs(:[]).with(:color).returns(true)
      subject.colorize(:red, 'version').should == "\e[0;31mversion\e[0m"
    end

    it "should withhold color output when not appropriate" do
      Puppet.stubs(:[]).with(:color).returns(false)
      subject.colorize(:red, 'version').should == "version"
    end

    it "should handle multiple overlapping colors in a stack-like way" do
      Puppet.stubs(:[]).with(:color).returns(true)
      vstring = subject.colorize(:red, 'version')
      subject.colorize(:green, "(#{vstring})").should == "\e[0;32m(\e[0;31mversion\e[0;32m)\e[0m"
    end

    it "should handle resets in a stack-like way" do
      Puppet.stubs(:[]).with(:color).returns(true)
      vstring = subject.colorize(:reset, 'version')
      subject.colorize(:green, "(#{vstring})").should == "\e[0;32m(\e[mversion\e[0;32m)\e[0m"
    end
  end
end

describe Puppet::Util::Log.desttypes[:new_console] do
  describe "when color is available" do
    it "should support color output" do
      Puppet.stubs(:[]).with(:color).returns(true)
      subject.colorize(:red, 'version').should == "\e[0;31mversion\e[0m"
    end

    it "should withhold color output when not appropriate" do
      Puppet.stubs(:[]).with(:color).returns(false)
      subject.colorize(:red, 'version').should == "version"
    end

    it "should handle multiple overlapping colors in a stack-like way" do
      Puppet.stubs(:[]).with(:color).returns(true)
      vstring = subject.colorize(:red, 'version')
      subject.colorize(:green, "(#{vstring})").should == "\e[0;32m(\e[0;31mversion\e[0;32m)\e[0m"
    end

    it "should handle resets in a stack-like way" do
      Puppet.stubs(:[]).with(:color).returns(true)
      vstring = subject.colorize(:reset, 'version')
      subject.colorize(:green, "(#{vstring})").should == "\e[0;32m(\e[mversion\e[0;32m)\e[0m"
    end
  end
end
