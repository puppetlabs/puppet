#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::TemplateWrapper do
    before(:each) do
        compiler = stub('compiler', :environment => "foo")
        parser = stub('parser', :watch_file => true)
        @scope = stub('scope', :compiler => compiler, :parser => parser)
        @file = "fake_template"
        Puppet::Module.stubs(:find_template).returns("/tmp/fake_template")
        FileTest.stubs(:exists?).returns("true")
        @tw = Puppet::Parser::TemplateWrapper.new(@scope, @file)
    end

    it "should create a new object TemplateWrapper from a scope and a file" do
        Puppet::Module.expects(:find_template).with("fake_template", "foo").returns("/tmp/fake_template")
        FileTest.expects(:exists?).with("/tmp/fake_template").returns(true)
        tw = Puppet::Parser::TemplateWrapper.new(@scope, @file)
        tw.should be_a_kind_of(Puppet::Parser::TemplateWrapper)
    end

    it "should turn into a string like template[name]" do
        @tw.to_s.should eql("template[/tmp/fake_template]")
    end

    it "should return the processed template contents with a call to result" do
        template_mock = mock("template", :result => "woot!")
        File.expects(:read).with("/tmp/fake_template").returns("template contents")
        ERB.expects(:new).with("template contents", 0, "-").returns(template_mock)
        @tw.result.should eql("woot!")
    end

    it "should return the contents of a variable if called via method_missing" do
        @scope.expects(:lookupvar).with("chicken", false).returns("is good")
        tw = Puppet::Parser::TemplateWrapper.new(@scope, @file)
        tw.chicken.should eql("is good")
    end

    it "should throw an exception if a variable is called via method_missing and it does not exist" do
        @scope.expects(:lookupvar).with("chicken", false).returns(:undefined)
        tw = Puppet::Parser::TemplateWrapper.new(@scope, @file)
        lambda { tw.chicken }.should raise_error(Puppet::ParseError)        
    end

    it "should allow you to check whether a variable is defined with has_variable?" do
        @scope.expects(:lookupvar).with("chicken", false).returns("is good")
        tw = Puppet::Parser::TemplateWrapper.new(@scope, @file)
        tw.has_variable?("chicken").should eql(true)
    end

    it "should allow you to check whether a variable is not defined with has_variable?" do
        @scope.expects(:lookupvar).with("chicken", false).returns(:undefined)
        tw = Puppet::Parser::TemplateWrapper.new(@scope, @file)
        tw.has_variable?("chicken").should eql(false)
    end
end
