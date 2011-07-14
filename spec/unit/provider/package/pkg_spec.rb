#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pkg) do
  before :each do
    @resource = Puppet::Resource.new(:package, 'dummy', :parameters => {:name => 'dummy', :ensure => :latest})
    @provider = described_class.new(@resource)
  end

  def self.it_should_respond_to(*actions)
    actions.each do |action|
      it "should respond to :#{action}" do
        @provider.should respond_to(action)
      end
    end
  end

  it_should_respond_to :install, :uninstall, :update, :query, :latest

  it "should not be versionable" do
    described_class.should_not be_versionable
  end

  it "should use :install to update" do
    @provider.expects(:install)
    @provider.update
  end

  it "should parse a line correctly" do
    result = described_class.parse_line("dummy 1.0@1.0-1.0 installed ----")
    result.should == {:name => "dummy", :version => "1.0@1.0-1.0",
      :ensure => :present, :status => "installed",
      :provider => :pkg}
  end

  it "should fail to parse an incorrect line" do
    result = described_class.parse_line("foo")
    result.should be_nil
  end

  it "should fail to list a missing package" do
    # I dont know what the acutal error looks like, but according to type/pkg.rb we're just
    # reacting on the Exception anyways
    @provider.expects(:pkg).with(:list, "-H", "dummy").raises Puppet::ExecutionFailure, 'Not found'
    @provider.query.should == {:ensure => :absent, :name => "dummy"}
  end

  it "should fail to list a package when it can't parse the output line" do
    @provider.expects(:pkg).with(:list, "-H", "dummy").returns "failed"
    @provider.query.should == {:ensure => :absent, :name => "dummy"}
  end

  it "should list package correctly" do
    @provider.expects(:pkg).with(:list, "-H", "dummy").returns "dummy 1.0@1.0-1.0 installed ----"
    @provider.query.should == {
      :name     => "dummy",
      :version  => "1.0@1.0-1.0",
      :ensure   => :present,
      :status   => "installed",
      :provider => :pkg
    }
  end
end
