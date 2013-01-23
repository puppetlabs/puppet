#! /usr/bin/env ruby
require 'spec_helper'

require 'tempfile'
require 'puppet/util/loadedfile_always_stale'

describe Puppet::Util::LoadedFileAlwaysStale do
  include PuppetSpec::Files
  before(:each) do
    @f = Tempfile.new('loadedfile_test')
    @f.puts "yayness"
    @f.flush

    fake_ctime = Time.now - (2 * Puppet[:filetimeout])
    @stat = stub('stat', :ctime => fake_ctime)
    @fake_now = Time.now + (2 * Puppet[:filetimeout])
  end

  # Compare to tests for 'spec/unit/util/loadedfile_spec.rb' where the corresponding test
  # returns false.
  it "should report a non stale file to be stale when asked to do so" do
    @loaded = Puppet::Util::LoadedFileAlwaysStale.new(@f.path)
    Time.stubs(:now).returns(@fake_now)
    @loaded.changed?.should_not == false
  end

  after(:each) do
    @f.close
  end
end
