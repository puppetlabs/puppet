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

