#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Scope do
    before :each do
        @scope = Puppet::Parser::Scope.new()
        @topscope = Puppet::Parser::Scope.new()
        @scope.stubs(:parent).returns(@topscope)
    end

    describe Puppet::Parser::Scope, "when setvar is called with append=true" do

        it "should raise error if the variable is already defined in this scope" do
            @scope.setvar("var","1",nil,nil,false)
            lambda { @scope.setvar("var","1",nil,nil,true) }.should raise_error(Puppet::ParseError)
        end

        it "it should lookup current variable value" do
            @scope.expects(:lookupvar).with("var").returns("2")
            @scope.setvar("var","1",nil,nil,true)
        end

        it "it should store the concatenated string '42'" do
            @topscope.setvar("var","4",nil,nil,false)
            @scope.setvar("var","2",nil,nil,true)
            @scope.lookupvar("var").should == "42"
        end

        it "it should store the concatenated array [4,2]" do
            @topscope.setvar("var",[4],nil,nil,false)
            @scope.setvar("var",[2],nil,nil,true)
            @scope.lookupvar("var").should == [4,2]
        end

    end
end
