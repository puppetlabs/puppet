#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/ldap'

describe Puppet::Indirector::Ldap do
  before do
    @indirection = stub 'indirection', :name => :testing
    Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)
    module Testing; end
    @ldap_class = class Testing::MyLdap < Puppet::Indirector::Ldap
      self
    end

    @connection = mock 'ldap'

    @searcher = @ldap_class.new
  end

  describe "when searching ldap" do
    before do
      # Stub everything, and we can selectively replace with an expect as
      # we need to for testing.
      @searcher.stubs(:connection).returns(@connection)
      @searcher.stubs(:search_filter).returns(:filter)
      @searcher.stubs(:search_base).returns(:base)
      @searcher.stubs(:process)

      @request = stub 'request', :key => "yay"
    end

    it "should call the ldapsearch method with the search filter" do
      @searcher.expects(:search_filter).with("yay").returns("yay's filter")
      @searcher.expects(:ldapsearch).with("yay's filter")
      @searcher.find @request
    end

    it "should fail if no block is passed to the ldapsearch method" do
      expect { @searcher.ldapsearch("blah") }.to raise_error(ArgumentError)
    end

    it "should use the results of the ldapbase method as the ldap search base" do
      @searcher.stubs(:search_base).returns("mybase")
      @connection.expects(:search).with do |*args|
        expect(args[0]).to eq("mybase")
        true
      end
      @searcher.find @request
    end

    it "should default to the value of the :search_base setting as the result of the ldapbase method" do
      Puppet[:ldapbase] = "myldapbase"
      searcher = @ldap_class.new
      expect(searcher.search_base).to eq("myldapbase")
    end

    it "should use the results of the :search_attributes method as the list of attributes to return" do
      @searcher.stubs(:search_attributes).returns(:myattrs)
      @connection.expects(:search).with do |*args|
        expect(args[3]).to eq(:myattrs)
        true
      end
      @searcher.find @request
    end

    it "should use depth 2 when searching" do
      @connection.expects(:search).with do |*args|
        expect(args[1]).to eq(2)
        true
      end
      @searcher.find @request
    end

    it "should call process() on the first found entry" do
      @connection.expects(:search).yields("myresult")
      @searcher.expects(:process).with("myresult")
      @searcher.find @request
    end

    it "should reconnect and retry the search if there is a failure" do
      run = false
      @connection.stubs(:search).with do |*args|
        if run
          true
        else
          run = true
          raise "failed"
        end
      end.yields("myresult")
      @searcher.expects(:process).with("myresult")

      @searcher.find @request
    end

    it "should not reconnect on failure more than once" do
      count = 0
      @connection.stubs(:search).with do |*args|
        count += 1
        raise ArgumentError, "yay"
      end
      expect { @searcher.find(@request) }.to raise_error(Puppet::Error)
      expect(count).to eq(2)
    end

    it "should return true if an entry is found" do
      @connection.expects(:search).yields("result")
      expect(@searcher.ldapsearch("whatever") { |r| }).to be_truthy
    end
  end

  describe "when connecting to ldap", :if => Puppet.features.ldap? do
    it "should create and start a Util::Ldap::Connection instance" do
      conn = double 'connection', :connection => "myconn", :start => nil
      Puppet::Util::Ldap::Connection.expects(:instance).returns conn

      expect(@searcher.connection).to eq("myconn")
    end

    it "should only create the ldap connection when asked for it the first time" do
      conn = double 'connection', :connection => "myconn", :start => nil
      Puppet::Util::Ldap::Connection.expects(:instance).returns conn

      @searcher.connection
    end

    it "should cache the connection" do
      conn = double 'connection', :connection => "myconn", :start => nil
      Puppet::Util::Ldap::Connection.expects(:instance).returns conn

      expect(@searcher.connection).to equal(@searcher.connection)
    end
  end

  describe "when reconnecting to ldap", :if => (Puppet.features.root? and Facter.value("hostname") == "culain") do
    it "should reconnect to ldap when connections are lost"
  end
end
