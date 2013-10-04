#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/json_lockfile'

describe Puppet::Util::JsonLockfile do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before(:each) do
    @lockfile = tmpfile("lock")
    @lock = Puppet::Util::JsonLockfile.new(@lockfile)
  end

  describe "#lock" do
    it "should create a lock file containing a json hash" do
      data = { "foo" => "foofoo", "bar" => "barbar" }
      @lock.lock(data)

      PSON.parse(File.read(@lockfile)).should == data
    end
  end

  it "should return the lock data" do
    data = { "foo" => "foofoo", "bar" => "barbar" }
    @lock.lock(data)
    @lock.lock_data.should == data
  end
end
