#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/ldap/node'

describe Puppet::Indirector::Ldap::Node, " when searching for nodes" do
    before do
        @searcher = Puppet::Indirector::Ldap::Node.new
    end

    it "should return the value of the :ldapclassattrs split on commas as the class attributes" do
        Puppet.stubs(:[]).with(:ldapclassattrs).returns("one,two")
        @searcher.class_attributes.should == %w{one two}
    end

    it "should return nil as the parent attribute if the :ldapparentattr is set to an empty string" do
        Puppet.stubs(:[]).with(:ldapparentattr).returns("")
        @searcher.parent_attribute.should be_nil
    end

    it "should return the value of the :ldapparentattr as the parent attribute" do
        Puppet.stubs(:[]).with(:ldapparentattr).returns("pere")
        @searcher.parent_attribute.should == "pere"
    end

    it "should use the value of the :ldapstring as the search filter" do
        Puppet.stubs(:[]).with(:ldapstring).returns("mystring")
        @searcher.search_filter("testing").should == "mystring"
    end

    it "should replace '%s' with the node name in the search filter if it is present" do
        Puppet.stubs(:[]).with(:ldapstring).returns("my%sstring")
        @searcher.search_filter("testing").should == "mytestingstring"
    end

    it "should not modify the global :ldapstring when replacing '%s' in the search filter" do
        filter = mock 'filter'
        filter.expects(:include?).with("%s").returns(true)
        filter.expects(:gsub).with("%s", "testing").returns("mynewstring")
        Puppet.stubs(:[]).with(:ldapstring).returns(filter)
        @searcher.search_filter("testing").should == "mynewstring"
    end
end

describe Puppet::Indirector::Ldap::Node, " when deciding attributes to search for" do
    before do
        @searcher = Puppet::Indirector::Ldap::Node.new
    end

    it "should use 'nil' if the :ldapattrs setting is 'all'" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("all")
        @searcher.search_attributes.should be_nil
    end

    it "should split the value of :ldapattrs on commas and use the result as the attribute list" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
        @searcher.stubs(:class_attributes).returns([])
        @searcher.stubs(:parent_attribute).returns(nil)
        @searcher.search_attributes.should == %w{one two}
    end

    it "should add the class attributes to the search attributes if not returning all attributes" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
        @searcher.stubs(:class_attributes).returns(%w{three four})
        @searcher.stubs(:parent_attribute).returns(nil)
        # Sort them so i don't have to care about return order
        @searcher.search_attributes.sort.should == %w{one two three four}.sort
    end

    it "should add the parent attribute to the search attributes if not returning all attributes" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
        @searcher.stubs(:class_attributes).returns([])
        @searcher.stubs(:parent_attribute).returns("parent")
        @searcher.search_attributes.sort.should == %w{one two parent}.sort
    end

    it "should not add nil parent attributes to the search attributes" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
        @searcher.stubs(:class_attributes).returns([])
        @searcher.stubs(:parent_attribute).returns(nil)
        @searcher.search_attributes.should == %w{one two}
    end
end
