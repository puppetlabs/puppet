require 'spec_helper'

require 'puppet/indirector/ldap'

describe Puppet::Indirector::Ldap do
  before do
    @indirection = double('indirection', :name => :testing)
    allow(Puppet::Indirector::Indirection).to receive(:instance).and_return(@indirection)
    module Testing; end
    @ldap_class = class Testing::MyLdap < Puppet::Indirector::Ldap
      self
    end

    @connection = double('ldap')
  end

  describe "when instantiating ldap" do
    it "should be deprecated" do
      expect(Puppet).to receive(:deprecation_warning).with("Puppet::Indirector::Ldap is deprecated and will be removed in a future release of Puppet.")

      @ldap_class.new
    end

    it "should not emit a deprecation warning when they are disabled" do
      expect(Puppet).not_to receive(:warning).with(/Puppet::Indirector::Ldap is deprecated/)
      Puppet[:disable_warnings] = ['deprecations']

      @ldap_class.new
    end

    it "should only emit the deprecation warning once" do
      expect(Puppet).to receive(:warning).with(/Puppet::Indirector::Ldap is deprecated/).once

      @ldap_class.new
      @ldap_class.new
    end
  end

  describe "when searching ldap" do
    before do
      @searcher = @ldap_class.new
      # Stub everything, and we can selectively replace with an expect as
      # we need to for testing.
      allow(@searcher).to receive(:connection).and_return(@connection)
      allow(@searcher).to receive(:search_filter).and_return(:filter)
      allow(@searcher).to receive(:search_base).and_return(:base)
      allow(@searcher).to receive(:process)

      @request = double('request', :key => "yay")
    end

    it "should call the ldapsearch method with the search filter" do
      expect(@searcher).to receive(:search_filter).with("yay").and_return("yay's filter")
      expect(@searcher).to receive(:ldapsearch).with("yay's filter")
      @searcher.find @request
    end

    it "should fail if no block is passed to the ldapsearch method" do
      expect { @searcher.ldapsearch("blah") }.to raise_error(ArgumentError)
    end

    it "should use the results of the ldapbase method as the ldap search base" do
      allow(@searcher).to receive(:search_base).and_return("mybase")
      expect(@connection).to receive(:search).with("mybase", anything, anything, anything)

      @searcher.find @request
    end

    it "should default to the value of the :search_base setting as the result of the ldapbase method" do
      Puppet[:ldapbase] = "myldapbase"
      searcher = @ldap_class.new
      expect(searcher.search_base).to eq("myldapbase")
    end

    it "should use the results of the :search_attributes method as the list of attributes to return" do
      allow(@searcher).to receive(:search_attributes).and_return(:myattrs)
      expect(@connection).to receive(:search).with(anything, anything, anything, :myattrs)

      @searcher.find @request
    end

    it "should use depth 2 when searching" do
      expect(@connection).to receive(:search).with(anything, 2, anything, anything)

      @searcher.find @request
    end

    it "should call process() on the first found entry" do
      expect(@connection).to receive(:search).and_yield("myresult")
      expect(@searcher).to receive(:process).with("myresult")
      @searcher.find @request
    end

    it "should reconnect and retry the search if there is a failure" do
      run = false
      allow(@connection).to receive(:search) do |*args|
        if run
          true
        else
          run = true
          raise "failed"
        end
      end.and_yield("myresult")
      expect(@searcher).to receive(:process).with("myresult")

      @searcher.find @request
    end

    it "should not reconnect on failure more than once" do
      count = 0
      allow(@connection).to receive(:search) do |*_|
        count += 1
        raise ArgumentError, "yay"
      end
      expect { @searcher.find(@request) }.to raise_error(Puppet::Error)
      expect(count).to eq(2)
    end

    it "should return true if an entry is found" do
      expect(@connection).to receive(:search).and_yield("result")
      expect(@searcher.ldapsearch("whatever") { |r| }).to be_truthy
    end
  end

  describe "when connecting to ldap", :if => Puppet.features.ldap? do
    it "should create and start a Util::Ldap::Connection instance" do
      conn = double('connection', :connection => "myconn", :start => nil)
      expect(Puppet::Util::Ldap::Connection).to receive(:instance).and_return(conn)

      expect(@searcher.connection).to eq("myconn")
    end

    it "should only create the ldap connection when asked for it the first time" do
      conn = double('connection', :connection => "myconn", :start => nil)
      expect(Puppet::Util::Ldap::Connection).to receive(:instance).and_return(conn)

      @searcher.connection
    end

    it "should cache the connection" do
      conn = double('connection', :connection => "myconn", :start => nil)
      expect(Puppet::Util::Ldap::Connection).to receive(:instance).and_return(conn)

      expect(@searcher.connection).to equal(@searcher.connection)
    end
  end

  describe "when reconnecting to ldap", :if => (Puppet.features.root? and Facter.value("hostname") == "culain") do
    it "should reconnect to ldap when connections are lost"
  end
end
