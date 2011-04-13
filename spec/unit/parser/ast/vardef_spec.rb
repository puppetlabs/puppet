#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::AST::VarDef do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  describe "when evaluating" do

    it "should evaluate arguments" do
      name = mock 'name'
      value = mock 'value'

      name.expects(:safeevaluate).with(@scope)
      value.expects(:safeevaluate).with(@scope)

      vardef = Puppet::Parser::AST::VarDef.new :name => name, :value => value, :file => nil, :line => nil
      vardef.evaluate(@scope)
    end

    it "should be in append=false mode if called without append" do
      name = stub 'name', :safeevaluate => "var"
      value = stub 'value', :safeevaluate => "1"

      @scope.expects(:setvar).with { |name,value,options| options[:append] == nil }

      vardef = Puppet::Parser::AST::VarDef.new :name => name, :value => value, :file => nil, :line => nil
      vardef.evaluate(@scope)
    end

    it "should call scope in append mode if append is true" do
      name = stub 'name', :safeevaluate => "var"
      value = stub 'value', :safeevaluate => "1"

      @scope.expects(:setvar).with { |name,value,options| options[:append] == true }

      vardef = Puppet::Parser::AST::VarDef.new :name => name, :value => value, :file => nil, :line => nil, :append => true
      vardef.evaluate(@scope)
    end

    it "should call pass the source location to setvar" do
      name = stub 'name', :safeevaluate => "var"
      value = stub 'value', :safeevaluate => "1"

      @scope.expects(:setvar).with { |name,value,options| options[:file] == 'setvar.pp' and options[:line] == 917 }

      vardef = Puppet::Parser::AST::VarDef.new :name => name, :value => value, :file => 'setvar.pp', :line => 917
      vardef.evaluate(@scope)
    end

    describe "when dealing with hash" do
      it "should delegate to the HashOrArrayAccess assign" do
        access = stub 'name'
        access.stubs(:is_a?).with(Puppet::Parser::AST::HashOrArrayAccess).returns(true)
        value = stub 'value', :safeevaluate => "1"
        vardef = Puppet::Parser::AST::VarDef.new :name => access, :value => value, :file => nil, :line => nil

        access.expects(:assign).with(@scope, '1')

        vardef.evaluate(@scope)
      end
    end

  end
end
