#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::Resource::Reference do
    before do
        @type = Puppet::Parser::Resource::Reference
    end

    it "should use the file lookup module" do
        Puppet::Parser::Resource::Reference.ancestors.should be_include(Puppet::FileCollection::Lookup)
    end

    it "should require a type" do
        proc { @type.new(:title => "yay") }.should raise_error(Puppet::DevError)
    end

    it "should require a title" do
        proc { @type.new(:type => "file") }.should raise_error(Puppet::DevError)
    end

    it "should know when it refers to a builtin type" do
        ref = @type.new(:type => "file", :title => "/tmp/yay")
        ref.builtin?.should be_true
        ref.builtintype.should equal(Puppet::Type.type(:file))
    end

    it "should return a downcased relationship-style resource reference for defined types" do
        ref = @type.new(:type => "file", :title => "/tmp/yay")
        ref.to_ref.should == ["file", "/tmp/yay"]
    end

    it "should return a capitalized relationship-style resource reference for defined types" do
        ref = @type.new(:type => "whatever", :title => "/tmp/yay")
        ref.to_ref.should == ["Whatever", "/tmp/yay"]
    end

    it "should return a resource reference string when asked" do
        ref = @type.new(:type => "file", :title => "/tmp/yay")
        ref.to_s.should == "File[/tmp/yay]"
    end

    it "should canonize resource reference types" do
        ref = @type.new(:type => "foo::bar", :title => "/tmp/yay")
        ref.to_s.should == "Foo::Bar[/tmp/yay]"
    end

    it "should canonize resource reference values" do
        ref = @type.new(:type => "file", :title => "/tmp/yay/")
        ref.to_s.should == "File[/tmp/yay]"
    end

    it "should canonize resource reference values without order dependencies" do
        args = [[:title, "/tmp/yay/"], [:type, "file"]]
        ref = @type.new(args)
        ref.to_s.should == "File[/tmp/yay]"
    end

end

describe Puppet::Parser::Resource::Reference, " when modeling defined types" do
    before do
        @type = Puppet::Parser::Resource::Reference

        @parser = Puppet::Parser::Parser.new :Code => ""
        @definition = @parser.newdefine "mydefine"
        @class = @parser.newclass "myclass"
        @nodedef = @parser.newnode("mynode")[0]
        @node = Puppet::Node.new("yaynode")

        @compiler = Puppet::Parser::Compiler.new(@node, @parser)
    end

    it "should be able to find defined types" do
        ref = @type.new(:type => "mydefine", :title => "/tmp/yay", :scope => @compiler.topscope)
        ref.builtin?.should be_false
        ref.definedtype.should equal(@definition)
    end

    it "should be able to find classes" do
        ref = @type.new(:type => "class", :title => "myclass", :scope => @compiler.topscope)
        ref.builtin?.should be_false
        ref.definedtype.should equal(@class)
    end

    it "should be able to find nodes" do
        ref = @type.new(:type => "node", :title => "mynode", :scope => @compiler.topscope)
        ref.builtin?.should be_false
        ref.definedtype.object_id.should  == @nodedef.object_id
    end

    it "should only look for fully qualified classes" do
        top = @parser.newclass "top"
        sub = @parser.newclass "other::top"

        scope = @compiler.topscope.class.new(:parent => @compiler.topscope, :namespace => "other", :parser => @parser)

        ref = @type.new(:type => "class", :title => "top", :scope => scope)
        ref.definedtype.name.should equal(top.name)
    end

    it "should only look for fully qualified definitions" do
        top = @parser.newdefine "top"
        sub = @parser.newdefine "other::top"

        scope = @compiler.topscope.class.new(:parent => @compiler.topscope, :namespace => "other", :parser => @parser)

        ref = @type.new(:type => "top", :title => "foo", :scope => scope)
        ref.definedtype.name.should equal(top.name)
    end
end
