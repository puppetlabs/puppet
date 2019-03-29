require 'spec_helper'
require 'puppet'

RSpec::Matchers.define_negated_matcher :neq, :eq

module Puppet::Util::Plist
end

describe Puppet::Type.type(:macauthorization).provider(:macauthorization) do
  before :each do
    # Create a mock resource
    @resource = double('resource')

    @authname = "foo.spam.eggs.puppettest"
    @authplist = {}

    @rules = {@authname => @authplist}

    authdb = {}
    authdb["rules"] = { "foorule" => "foo" }
    authdb["rights"] = { "fooright" => "foo" }

    # Stub out Plist::parse_xml
    allow(Puppet::Util::Plist).to receive(:parse_plist).and_return(authdb)
    allow(Puppet::Util::Plist).to receive(:write_plist_file)

    # A catch all; no parameters set
    allow(@resource).to receive(:[]).and_return(nil)

    # But set name, ensure
    allow(@resource).to receive(:[]).with(:name).and_return(@authname)
    allow(@resource).to receive(:[]).with(:ensure).and_return(:present)
    allow(@resource).to receive(:ref).and_return("MacAuthorization[#{@authname}]")

    @provider = described_class.new(@resource)
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
      allow(@resource).to receive(:[]).with(:auth_type).and_return(:right)
    end

    it "should call the internal method destroy_right" do
      expect(@provider).to receive(:destroy_right)
      @provider.destroy
    end
    it "should call the external command 'security authorizationdb remove @authname" do
      expect(@provider).to receive(:security).with("authorizationdb", :remove, @authname)
      @provider.destroy
    end
  end

  describe "when destroying a rule" do
    before :each do
      allow(@resource).to receive(:[]).with(:auth_type).and_return(:rule)
    end

    it "should call the internal method destroy_rule" do
      expect(@provider).to receive(:destroy_rule)
      @provider.destroy
    end
  end

  describe "when flushing a right" do
    before :each do
      allow(@resource).to receive(:[]).with(:auth_type).and_return(:right)
    end

    it "should call the internal method flush_right" do
      expect(@provider).to receive(:flush_right)
      @provider.flush
    end

    it "should call the internal method set_right" do
      expect(@provider).to receive(:execute).with(include("read").and(include(@authname)), hash_including(combine: false)).once
      expect(@provider).to receive(:set_right)
      @provider.flush
    end

    it "should read and write to the auth database with the right arguments" do
      expect(@provider).to receive(:execute).with(include("read").and(include(@authname)), hash_including(combine: false)).once
      expect(@provider).to receive(:execute).with(include("write").and(include(@authname)), hash_including(combine: false, stdinfile: neq(nil))).once

      @provider.flush
    end

  end

  describe "when flushing a rule" do
    before :each do
      allow(@resource).to receive(:[]).with(:auth_type).and_return(:rule)
    end

    it "should call the internal method flush_rule" do
      expect(@provider).to receive(:flush_rule)
      @provider.flush
    end

    it "should call the internal method set_rule" do
      expect(@provider).to receive(:set_rule)
      @provider.flush
    end
  end
end
