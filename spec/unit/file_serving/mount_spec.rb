#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/file_serving/mount'

describe Puppet::FileServing::Mount do
  it "should use 'mount[$name]' as its string form" do
    expect(Puppet::FileServing::Mount.new("foo").to_s).to eq("mount[foo]")
  end
end

describe Puppet::FileServing::Mount, " when initializing" do
  it "should fail on non-alphanumeric name" do
    expect { Puppet::FileServing::Mount.new("non alpha") }.to raise_error(ArgumentError)
  end

  it "should allow dashes in its name" do
    expect(Puppet::FileServing::Mount.new("non-alpha").name).to eq("non-alpha")
  end
end

describe Puppet::FileServing::Mount, " when finding files" do
  it "should fail" do
    expect { Puppet::FileServing::Mount.new("test").find("foo", :one => "two") }.to raise_error(NotImplementedError)
  end
end

describe Puppet::FileServing::Mount, " when searching for files" do
  it "should fail" do
    expect { Puppet::FileServing::Mount.new("test").search("foo", :one => "two") }.to raise_error(NotImplementedError)
  end
end
