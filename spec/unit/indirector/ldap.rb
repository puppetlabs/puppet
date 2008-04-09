#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/ldap'

describe Puppet::Indirector::Ldap, " when searching ldap" do
    before do
        @indirection = stub 'indirection', :name => :testing
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)
        @ldap_class = Class.new(Puppet::Indirector::Ldap) do
            def self.to_s
                "Testing::Mytype"
            end
        end

        @connection = mock 'ldap'

        @searcher = @ldap_class.new

        # Stub everything, and we can selectively replace with an expect as
        # we need to for testing.
        @searcher.stubs(:connection).returns(@connection)
        @searcher.stubs(:search_filter).returns(:filter)
        @searcher.stubs(:search_base).returns(:base)
        @searcher.stubs(:process)

        @request = stub 'request', :key => "yay"
    end

    it "should call the ldapsearch method with the name being searched for" do
        @searcher.expects(:ldapsearch).with("yay")
        @searcher.find @request
    end

    it "should fail if no block is passed to the ldapsearch method" do
        proc { @searcher.ldapsearch("blah") }.should raise_error(ArgumentError)
    end

    it "should use the results of the ldapbase method as the ldap search base" do
        @searcher.stubs(:search_base).returns("mybase")
        @connection.expects(:search).with do |*args|
            args[0].should == "mybase"
            true
        end
        @searcher.find @request
    end

    it "should default to the value of the :search_base setting as the result of the ldapbase method" do
        Puppet.expects(:[]).with(:ldapbase).returns("myldapbase")
        searcher = @ldap_class.new
        searcher.search_base.should == "myldapbase"
    end

    it "should use the results of the :search_attributes method as the list of attributes to return" do
        @searcher.stubs(:search_attributes).returns(:myattrs)
        @connection.expects(:search).with do |*args|
            args[3].should == :myattrs
            true
        end
        @searcher.find @request
    end

    it "should use the results of the :search_filter method as the search filter" do
        @searcher.stubs(:search_filter).with("yay").returns("yay's filter")
        @connection.expects(:search).with do |*args|
            args[2].should == "yay's filter"
            true
        end
        @searcher.find @request
    end

    it "should use depth 2 when searching" do
        @connection.expects(:search).with do |*args|
            args[1].should == 2
            true
        end
        @searcher.find @request
    end

    it "should call process() on the first found entry" do
        @connection.expects(:search).yields("myresult")
        @searcher.expects(:process).with("yay", "myresult")
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
        @searcher.expects(:process).with("yay", "myresult")

        @searcher.find @request
    end

    it "should not reconnect on failure more than once" do
        count = 0
        @connection.stubs(:search).with do |*args|
            count += 1
            raise ArgumentError, "yay"
        end
        proc { @searcher.find(@request) }.should raise_error(Puppet::Error)
        count.should == 2
    end

    it "should return true if an entry is found" do
        @connection.expects(:search).yields("result")
        @searcher.ldapsearch("whatever") { |r| }.should be_true
    end
end

describe Puppet::Indirector::Ldap, " when connecting to ldap" do
    confine "LDAP is not available" => Puppet.features.ldap?
    confine "No LDAP test data for networks other than Luke's" => Facter.value(:domain) == "madstop.com"

    it "should only create the ldap connection when asked for it the first time"

    it "should throw an exception if it cannot connect to LDAP"

    it "should use SSL when the :ldapssl setting is true"

    it "should connect to the server specified in the :ldapserver setting"

    it "should use the port specified in the :ldapport setting"

    it "should use protocol version 3"

    it "should follow referrals"

    it "should use the user specified in the :ldapuser setting"

    it "should use the password specified in the :ldappassord setting"

    it "should have an ldap method that returns an LDAP connection object"

    it "should fail when LDAP support is missing"
end

describe Puppet::Indirector::Ldap, " when reconnecting to ldap" do
    confine "Not running on culain as root" => (Puppet::Util::SUIDManager.uid == 0 and Facter.value("hostname") == "culain")

    it "should reconnect to ldap when connections are lost"
end
