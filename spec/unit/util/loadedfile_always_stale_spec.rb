#! /usr/bin/env ruby
require 'spec_helper'

require 'tempfile'
require 'puppet/util/loadedfile'
require 'puppet/util/loadedfile_always_stale'

describe Puppet::Util::LoadedFileAlwaysStale do
  include PuppetSpec::Files
  before(:each) do
    @f = Tempfile.new('loadedfile_test')
    @f.puts "yayness"
    @f.flush

#    @loaded = Puppet::Util::LoadedFileAlwaysStale.new(@f.path)
#    @loaded2 = Puppet::Util::LoadedFileAlwaysStale.new(@f.path)

    fake_ctime = Time.now - (2 * Puppet[:filetimeout])
    @stat = stub('stat', :ctime => fake_ctime)
    @fake_now = Time.now + (2 * Puppet[:filetimeout])
  end

  it "should report a non stale file to be non stale when asked to do so" do
    loaded = Puppet::Util::LoadedFile.new(@f.path)
    Time.stubs(:now).returns(@fake_now)
    loaded.changed?.should == false
  end

  it "should report a non stale file to be stale when asked to do so" do
    @loaded = Puppet::Util::LoadedFileAlwaysStale.new(@f.path)
    Time.stubs(:now).returns(@fake_now)
    @loaded.changed?.should_not == false
  end

  after(:each) do
    @f.close
  end
end
