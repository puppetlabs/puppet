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

    describe Puppet::Parser::Scope, "when calling number?" do

        it "should return nil if called with anything not a number" do
            Puppet::Parser::Scope.number?([2]).should be_nil
        end

        it "should return a Fixnum for a Fixnum" do
            Puppet::Parser::Scope.number?(2).should be_an_instance_of(Fixnum)
        end

        it "should return a Float for a Float" do
            Puppet::Parser::Scope.number?(2.34).should be_an_instance_of(Float)
        end

        it "should return 234 for '234'" do
            Puppet::Parser::Scope.number?("234").should == 234
        end

        it "should return nil for 'not a number'" do
            Puppet::Parser::Scope.number?("not a number").should be_nil
        end

        it "should return 23.4 for '23.4'" do
            Puppet::Parser::Scope.number?("23.4").should == 23.4
        end

        it "should return 23.4e13 for '23.4e13'" do
            Puppet::Parser::Scope.number?("23.4e13").should == 23.4e13
        end

        it "should understand negative numbers" do
            Puppet::Parser::Scope.number?("-234").should == -234
        end

        it "should know how to convert exponential float numbers ala '23e13'" do
            Puppet::Parser::Scope.number?("23e13").should == 23e13
        end

        it "should understand hexadecimal numbers" do
            Puppet::Parser::Scope.number?("0x234").should == 0x234
        end

        it "should understand octal numbers" do
            Puppet::Parser::Scope.number?("0755").should == 0755
        end


    end

end
