#!/usr/bin/env rspec
require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:pkg)

describe provider do
  before do
    @resource = stub 'resource', :[] => "dummy"
    @provider = provider.new(@resource)

    @fakeresult = "install ok installed dummy 1.0\n"
  end

  def self.it_should_respond_to(*actions)
    actions.each do |action|
      it "should respond to :#{action}" do
        @provider.should respond_to(action)
      end
    end
  end

  it_should_respond_to :install, :uninstall, :update, :query, :latest

  it "should be versionable" do
    provider.should_not be_versionable
  end

  it "should use :install to update" do
    @provider.expects(:install)
    @provider.update
  end

  it "should parse a line correctly" do
    result = provider.parse_line("dummy 1.0@1.0-1.0 installed ----")
    result.should == {:name => "dummy", :version => "1.0@1.0-1.0",
      :ensure => :present, :status => "installed",
      :provider => :pkg, :error => "ok"}
  end

  it "should fail to parse an incorrect line" do
    result = provider.parse_line("foo")
    result.should be_nil
  end

  it "should fail to list a missing package" do
    @provider.expects(:pkg).with(:list, "-H", "dummy").returns "1"
    @provider.query.should == {:status=>"missing", :ensure=>:absent,
      :name=>"dummy", :error=>"ok"}
  end

  it "should fail to list a package when it can't parse the output line" do
    @provider.expects(:pkg).with(:list, "-H", "dummy").returns "failed"
    @provider.query.should == {:status=>"missing", :ensure=>:absent, :name=>"dummy", :error=>"ok"}
  end

  it "should list package correctly" do
    @provider.expects(:pkg).with(:list, "-H", "dummy").returns "dummy 1.0@1.0-1.0 installed ----"
    @provider.query.should == {:name => "dummy", :version => "1.0@1.0-1.0",
      :ensure => :present, :status => "installed",
      :provider => :pkg, :error => "ok"}
  end
end
