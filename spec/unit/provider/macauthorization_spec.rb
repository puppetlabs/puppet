#! /usr/bin/env ruby
#
# Unit testing for the macauthorization provider
#

require 'spec_helper'

require 'puppet'

module Puppet::Util::Plist
end

provider_class = Puppet::Type.type(:macauthorization).provider(:macauthorization)

describe provider_class do

  before :each do
    # Create a mock resource
    @resource = stub 'resource'

    @authname = "foo.spam.eggs.puppettest"
    @authplist = {}

    @rules = {@authname => @authplist}

    authdb = {}
    authdb["rules"] = { "foorule" => "foo" }
    authdb["rights"] = { "fooright" => "foo" }

    # Stub out Plist::parse_xml
    Puppet::Util::Plist.stubs(:parse_plist).returns(authdb)
    Puppet::Util::Plist.stubs(:write_plist_file)

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name, ensure
    @resource.stubs(:[]).with(:name).returns @authname
    @resource.stubs(:[]).with(:ensure).returns :present
    @resource.stubs(:ref).returns "MacAuthorization[#{@authname}]"

    @provider = provider_class.new(@resource)
  end

  it "should have a create method" do
    expect(@provider).to respond_to(:create)
  end

  it "should have a destroy method" do
    expect(@provider).to respond_to(:destroy)
  end

  it "should have an exists? method" do
    expect(@provider).to respond_to(:exists?)
  end

  it "should have a flush method" do
    expect(@provider).to respond_to(:flush)
  end

  properties = [  :allow_root, :authenticate_user, :auth_class, :comment,
            :group, :k_of_n, :mechanisms, :rule, :session_owner,
            :shared, :timeout, :tries, :auth_type ]

  properties.each do |prop|
    it "should have a #{prop.to_s} method" do
      expect(@provider).to respond_to(prop.to_s)
    end

    it "should have a #{prop.to_s}= method" do
      expect(@provider).to respond_to(prop.to_s + "=")
    end
  end

  describe "when destroying a right" do
    before :each do
      @resource.stubs(:[]).with(:auth_type).returns(:right)
    end

    it "should call the internal method destroy_right" do
      @provider.expects(:destroy_right)
      @provider.destroy
    end
    it "should call the external command 'security authorizationdb remove @authname" do
      @provider.expects(:security).with("authorizationdb", :remove, @authname)
      @provider.destroy
    end
  end

  describe "when destroying a rule" do
    before :each do
      @resource.stubs(:[]).with(:auth_type).returns(:rule)
    end

    it "should call the internal method destroy_rule" do
      @provider.expects(:destroy_rule)
      @provider.destroy
    end
  end

  describe "when flushing a right" do
    before :each do
      @resource.stubs(:[]).with(:auth_type).returns(:right)
    end

    it "should call the internal method flush_right" do
      @provider.expects(:flush_right)
      @provider.flush
    end

    it "should call the internal method set_right" do
      @provider.expects(:execute).with { |cmds, args|
        cmds.include?("read") and
        cmds.include?(@authname) and
        args[:combine] == false
      }.once
      @provider.expects(:set_right)
      @provider.flush
    end

    it "should read and write to the auth database with the right arguments" do
      @provider.expects(:execute).with { |cmds, args|
        cmds.include?("read") and
        cmds.include?(@authname) and
        args[:combine] == false
      }.once

      @provider.expects(:execute).with { |cmds, args|
        cmds.include?("write") and
        cmds.include?(@authname) and
        args[:combine] == false and
        args[:stdinfile] != nil
      }.once
      @provider.flush
    end

  end

  describe "when flushing a rule" do
    before :each do
      @resource.stubs(:[]).with(:auth_type).returns(:rule)
    end

    it "should call the internal method flush_rule" do
      @provider.expects(:flush_rule)
      @provider.flush
    end

    it "should call the internal method set_rule" do
      @provider.expects(:set_rule)
      @provider.flush
    end
  end

end
