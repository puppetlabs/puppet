#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Functions do

    before(:each) do
    end

    after(:each) do
        # Rationale:
        # our various tests will almost all register to Pupet::Parser::Functions
        # a new function called "name". All tests are required to stub Puppet::Parser::Scope
        # so that +no+ new real ruby method are defined.
        # After each test, we want to leave the whole Puppet::Parser::Functions environment
        # as it was before we were called, hence we call rmfunction (which might not succeed
        # if the function hasn't been registered in the test). It is also important in this
        # section to stub +remove_method+ here so that we don't pollute the scope.
        Puppet::Parser::Scope.stubs(:remove_method)
        begin
            Puppet::Parser::Functions.rmfunction("name")
        rescue
        end
    end

    describe "when calling newfunction" do
        it "should create the function in the scope class" do
            Puppet::Parser::Scope.expects(:define_method).with { |name,block| name == "function_name" }

            Puppet::Parser::Functions.newfunction("name", :type => :rvalue)
        end

        it "should raise an error if the function already exists" do
            Puppet::Parser::Scope.expects(:define_method).with { |name,block| name == "function_name" }.once
            Puppet::Parser::Functions.newfunction("name", :type => :rvalue)

            lambda { Puppet::Parser::Functions.newfunction("name", :type => :rvalue) }.should raise_error
        end

        it "should raise an error if the function type is not correct" do
            Puppet::Parser::Scope.expects(:define_method).with { |name,block| name == "function_name" }.never

            lambda { Puppet::Parser::Functions.newfunction("name", :type => :unknown) }.should raise_error
        end
    end

    describe "when calling rmfunction" do
        it "should remove the function in the scope class" do
            Puppet::Parser::Scope.expects(:define_method).with { |name,block| name == "function_name" }
            Puppet::Parser::Functions.newfunction("name", :type => :rvalue)

            Puppet::Parser::Scope.expects(:remove_method).with("function_name").once

            Puppet::Parser::Functions.rmfunction("name")
        end

        it "should raise an error if the function doesn't exists" do
            lambda { Puppet::Parser::Functions.rmfunction("name") }.should raise_error
        end
    end

    describe "when calling function to test function existance" do

        it "should return false if the function doesn't exist" do
            Puppet::Parser::Functions.autoloader.stubs(:load)

            Puppet::Parser::Functions.function("name").should be_false
        end

        it "should return it's name if the function exists" do
            Puppet::Parser::Scope.expects(:define_method).with { |name,block| name == "function_name" }
            Puppet::Parser::Functions.newfunction("name", :type => :rvalue)

            Puppet::Parser::Functions.function("name").should == "function_name"
        end

        it "should try to autoload the function if it doesn't exist yet" do
            Puppet::Parser::Functions.autoloader.expects(:load)

            Puppet::Parser::Functions.function("name")
        end
    end
end
