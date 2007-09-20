#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector'

describe Puppet::Indirector::Indirection, " when initializing" do
    it "should set the name" do
        @indirection = Puppet::Indirector::Indirection.new(:myind)
        @indirection.name.should == :myind
    end

    it "should set any passed options" do
        @indirection = Puppet::Indirector::Indirection.new(:myind, :to => :node_source)
        @indirection.to.should == :node_source
    end

    it "should only allow valid configuration parameters to be specified as :to targets" do
        proc { Puppet::Indirector::Indirection.new(:myind, :to => :no_such_variable) }.should raise_error(ArgumentError)
    end

    after do
        if defined? @indirection
            @indirection.delete
        end
    end
end

describe Puppet::Indirector::Indirection, " when managing termini" do
    before do
        @indirection = Puppet::Indirector::Indirection.new(:node, :to => :node_source)
    end

    it "should allow the clearance of cached termini" do
        terminus1 = mock 'terminus1'
        terminus2 = mock 'terminus2'
        Puppet::Indirector.terminus(:node, Puppet[:node_source]).stubs(:new).returns(terminus1, terminus2, ArgumentError)
        @indirection.terminus.should equal(terminus1)
        @indirection.class.clear_cache
        @indirection.terminus.should equal(terminus2)
    end

    # Make sure it caches the terminus.
    it "should return the same terminus each time" do
        @indirection = Puppet::Indirector::Indirection.new(:node, :to => :node_source)
        @terminus = mock 'new'
        Puppet::Indirector.terminus(:node, Puppet[:node_source]).expects(:new).returns(@terminus)

        @indirection.terminus.should equal(@terminus)
        @indirection.terminus.should equal(@terminus)
    end

    after do
        @indirection.delete
        Puppet::Indirector::Indirection.clear_cache
    end
end
