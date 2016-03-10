#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet'
require 'puppet_spec/files'
require 'semver'

describe Puppet do
  include PuppetSpec::Files

  context "#version" do
    it "should be valid semver" do
      expect(SemVer).to be_valid Puppet.version
    end
  end

  Puppet::Util::Log.eachlevel do |level|
    it "should have a method for sending '#{level}' logs" do
      expect(Puppet).to respond_to(level)
    end
  end

  it "should be able to change the path" do
    newpath = ENV["PATH"] + File::PATH_SEPARATOR + "/something/else"
    Puppet[:path] = newpath
    expect(ENV["PATH"]).to eq(newpath)
  end

  it "should change $LOAD_PATH when :libdir changes" do
    one = tmpdir('load-path-one')
    two = tmpdir('load-path-two')
    expect(one).not_to eq(two)

    Puppet[:libdir] = one
    expect($LOAD_PATH).to include one
    expect($LOAD_PATH).not_to include two

    Puppet[:libdir] = two
    expect($LOAD_PATH).not_to include one
    expect($LOAD_PATH).to include two
  end

  context "newtype" do
    it "should issue a deprecation warning" do
      subject.expects(:deprecation_warning).with("Creating sometype via Puppet.newtype is deprecated and will be removed in a future release. Use Puppet::Type.newtype instead.")
      subject.newtype("sometype")
    end
  end
end
