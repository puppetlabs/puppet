#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::Leaf do
    describe "when converting to string" do
        it "should transform its value to string" do
            value = stub 'value', :is_a? => true
            value.expects(:to_s)
            Puppet::Parser::AST::Leaf.new( :value => value ).to_s
        end
    end
end

describe Puppet::Parser::AST::FlatString do
    describe "when converting to string" do
        it "should transform its value to a quoted string" do
            value = stub 'value', :is_a? => true, :to_s => "ab"
            Puppet::Parser::AST::FlatString.new( :value => value ).to_s.should == "\"ab\""
        end
    end
end

describe Puppet::Parser::AST::FlatString do
    describe "when converting to string" do
        it "should transform its value to a quoted string" do
            value = stub 'value', :is_a? => true, :to_s => "ab"
            Puppet::Parser::AST::String.new( :value => value ).to_s.should == "\"ab\""
        end
    end
end
