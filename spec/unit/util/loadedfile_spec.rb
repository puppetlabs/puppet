#!/usr/bin/env rspec
require 'spec_helper'

require 'tempfile'
require 'puppet/util/loadedfile'

describe Puppet::Util::LoadedFile do
  include PuppetSpec::Files
  before(:each) do
    @f = Tempfile.new('loadedfile_test')
    @f.puts "yayness"
    @f.flush

    @loaded = Puppet::Util::LoadedFile.new(@f.path)

    fake_ctime = Time.now - (2 * Puppet[:filetimeout])
    @stat = stub('stat', :ctime => fake_ctime)
    @fake_now = Time.now + (2 * Puppet[:filetimeout])
  end

  it "should accept files that don't exist" do
    nofile = tmpfile('testfile')
    File.exists?(nofile).should == false
    lambda{ Puppet::Util::LoadedFile.new(nofile) }.should_not raise_error
  end

  it "should recognize when the file has not changed" do
    # Use fake "now" so that we can be sure changed? actually checks, without sleeping
    # for Puppet[:filetimeout] seconds.
    Time.stubs(:now).returns(@fake_now)
    @loaded.changed?.should == false
  end

  it "should recognize when the file has changed" do
    # Fake File.stat so we don't have to depend on the filesystem granularity. Doing a flush()
    # just didn't do the job.
    File.stubs(:stat).returns(@stat)
    # Use fake "now" so that we can be sure changed? actually checks, without sleeping
    # for Puppet[:filetimeout] seconds.
    Time.stubs(:now).returns(@fake_now)
    @loaded.changed?.should be_an_instance_of(Time)
  end

  it "should not catch a change until the timeout has elapsed" do
    # Fake File.stat so we don't have to depend on the filesystem granularity. Doing a flush()
    # just didn't do the job.
    File.stubs(:stat).returns(@stat)
    @loaded.changed?.should be(false)
    # Use fake "now" so that we can be sure changed? actually checks, without sleeping
    # for Puppet[:filetimeout] seconds.
    Time.stubs(:now).returns(@fake_now)
    @loaded.changed?.should_not be(false)
  end

  it "should consider a file changed when that file is missing" do
    @f.close!
    # Use fake "now" so that we can be sure changed? actually checks, without sleeping
    # for Puppet[:filetimeout] seconds.
    Time.stubs(:now).returns(@fake_now)
    @loaded.changed?.should_not be(false)
  end

  it "should disable checking if Puppet[:filetimeout] is negative" do
    Puppet[:filetimeout] = -1
    @loaded.changed?.should_not be(false)
  end

  after(:each) do
    @f.close
  end
end
