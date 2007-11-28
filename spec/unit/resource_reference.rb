#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/resource_reference'

describe Puppet::ResourceReference do
    it "should have a :title attribute" do
        Puppet::ResourceReference.new(:file, "foo").title.should == "foo"
    end

    it "should canonize types to capitalized strings" do
        Puppet::ResourceReference.new(:file, "foo").type.should == "File"
    end

    it "should canonize qualified types so all strings are capitalized" do
        Puppet::ResourceReference.new("foo::bar", "foo").type.should == "Foo::Bar"
    end
end

describe Puppet::ResourceReference, "when resolving resources without a configuration" do
    it "should be able to resolve builtin resources from their types" do
        Puppet::Type.type(:file).expects(:[]).with("myfile").returns(:myfile)
        Puppet::ResourceReference.new(:file, "myfile").resolve.should == :myfile
    end

    it "should be able to resolve defined resources from Components" do
        Puppet::Type.type(:component).expects(:[]).with("Foo::Bar[yay]").returns(:mything)
        Puppet::ResourceReference.new("foo::bar", "yay").resolve.should == :mything
    end
end

describe Puppet::ResourceReference, "when resolving resources with a configuration" do
    it "should resolve all resources using the configuration" do
        config = mock 'configuration'
        ref = Puppet::ResourceReference.new("foo::bar", "yay")
        ref.configuration = config

        config.expects(:resource).with("Foo::Bar[yay]").returns(:myresource)

        ref.resolve.should == :myresource
    end
end
