#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::VarDef do
    before :each do
        @scope = Puppet::Parser::Scope.new()
    end

    describe "when evaluating" do

        it "should evaluate arguments" do
            name = mock 'name'
            value = mock 'value'
            
            name.expects(:safeevaluate).with(@scope)
            value.expects(:safeevaluate).with(@scope)

            vardef = Puppet::Parser::AST::VarDef.new :name => name, :value => value, :file => nil,  
                                                     :line => nil
            vardef.evaluate(@scope)
        end

        it "should be in append=false mode if called without append" do
            name = stub 'name', :safeevaluate => "var"
            value = stub 'value', :safeevaluate => "1"
            
            @scope.expects(:setvar).with { |name,value,file,line,append| append == nil }
            
            vardef = Puppet::Parser::AST::VarDef.new :name => name, :value => value, :file => nil,  
                                                     :line => nil
            vardef.evaluate(@scope)
        end
        
        it "should call scope in append mode if append is true" do
            name = stub 'name', :safeevaluate => "var"
            value = stub 'value', :safeevaluate => "1"
            
            @scope.expects(:setvar).with { |name,value,file,line,append| append == true }
            
            vardef = Puppet::Parser::AST::VarDef.new :name => name, :value => value, :file => nil,  
                                                     :line => nil, :append => true
            vardef.evaluate(@scope)
        end

    end
end
