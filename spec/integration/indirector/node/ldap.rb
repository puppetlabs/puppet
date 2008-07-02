#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/node/ldap'

describe Puppet::Node::Ldap do
    before do
        Puppet[:node_terminus] = :ldap
        Puppet::Node.stubs(:terminus_class).returns :ldap
    end

    after do
        Puppet.settings.clear
    end

    it "should use a restrictive filter when searching for nodes in a class" do
        Puppet::Node.indirection.terminus(:ldap).expects(:ldapsearch).with("(&(objectclass=puppetClient)(puppetclass=foo))")

        Puppet::Node.search "eh", :class => "foo"
    end
end
