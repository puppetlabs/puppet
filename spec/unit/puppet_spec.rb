#!/usr/bin/env rspec"
require 'spec_helper'
require 'puppet'
require 'puppet_spec/files'

describe Puppet do
  include PuppetSpec::Files

  Puppet::Util::Log.eachlevel do |level|
    it "should have a method for sending '#{level}' logs" do
      Puppet.should respond_to(level)
    end
  end

  it "should be able to change the path" do
    newpath = ENV["PATH"] + ":/something/else"
    Puppet[:path] = newpath
    ENV["PATH"].should == newpath
  end

  it "should change $LOAD_PATH when :libdir changes" do
    one = tmpdir('load-path-one')
    two = tmpdir('load-path-two')
    one.should_not == two

    Puppet[:libdir] = one
    $LOAD_PATH.should include one
    $LOAD_PATH.should_not include two

    Puppet[:libdir] = two
    $LOAD_PATH.should_not include one
    $LOAD_PATH.should include two
  end
end
