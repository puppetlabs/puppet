#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::ResourceReference do

    ast = Puppet::Parser::AST

    before :each do
        @scope = Puppet::Parser::Scope.new()
    end

    def newref(title, type)
        title = stub 'title', :safeevaluate => title
        ref = Puppet::Parser::AST::ResourceReference.new(:type => type, :title => title)
    end

    it "should evaluate correctly reference to builtin types" do
        newref("/tmp/yay", "File").evaluate(@scope).to_s.should == "File[/tmp/yay]"
    end

    %{ "one::two" "one-two"}.each do |type|
        it "should evaluate correctly reference to define" do
            klass = stub 'klass', :title => "three", :name => type
            @scope.stubs(:find_definition).returns(klass)
        
            newref("three", type).evaluate(@scope).to_ref.should == Puppet::Parser::Resource::Reference.new( :type => type, :title => "three" ).to_ref
        end
    end

    it "should be able to call qualified_class" do
        klass = stub 'klass', :title => "three", :name => "one"
        @scope.expects(:find_hostclass).with("one").returns(klass)
        newref("three","class").qualified_class(@scope,"one").should == "one" 
    end

    it "should be able to find qualified classes when evaluating" do
        klass = stub 'klass', :title => "one", :name => "one"
        @scope.stubs(:find_hostclass).returns(klass)
        
        evaled = newref("one", "class").evaluate(@scope)
        evaled.type.should == "Class"
        evaled.title.should == "one"
    end

    it "should return an array of reference if given an array of titles" do
        titles = mock 'titles', :safeevaluate => ["title1","title2"]
        ref = ast::ResourceReference.new( :title => titles, :type => "Resource" )
        ref.stubs(:qualified_type).with(@scope).returns("Resource")

        ref.evaluate(@scope).should have(2).elements
    end

    it "should qualify class of all titles for Class resource references" do
        titles = mock 'titles', :safeevaluate => ["title1","title2"]
        ref = ast::ResourceReference.new( :title => titles, :type => "Class" )
        ref.expects(:qualified_class).with(@scope,"title1").returns("class")
        ref.expects(:qualified_class).with(@scope,"title2").returns("class")

        ref.evaluate(@scope)
    end

    it "should return a correct representation when converting to string" do
        type = stub 'type', :is_a? => true, :to_s => "file"
        title = stub 'title', :is_a? => true, :to_s => "[/tmp/a, /tmp/b]"

        ast::ResourceReference.new( :type => type, :title => title ).to_s.should == "File[/tmp/a, /tmp/b]"
    end
end
