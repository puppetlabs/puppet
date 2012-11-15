#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/file_serving/mount'

describe Puppet::FileServing::Mount do
  it "should use 'mount[$name]' as its string form" do
    Puppet::FileServing::Mount.new("foo").to_s.should == "mount[foo]"
  end
end

describe Puppet::FileServing::Mount, " when initializing" do
  it "should fail on non-alphanumeric name" do
    proc { Puppet::FileServing::Mount.new("non alpha") }.should raise_error(ArgumentError)
  end

  it "should allow dashes in its name" do
    Puppet::FileServing::Mount.new("non-alpha").name.should == "non-alpha"
  end
end

describe Puppet::FileServing::Mount, " when finding files" do
  it "should fail" do
    lambda { Puppet::FileServing::Mount.new("test").find("foo", :one => "two") }.should raise_error(NotImplementedError)
  end
end

describe Puppet::FileServing::Mount, " when searching for files" do
  it "should fail" do
    lambda { Puppet::FileServing::Mount.new("test").search("foo", :one => "two") }.should raise_error(NotImplementedError)
  end
end
