#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/string/action'

describe Puppet::String::Action do
  describe "when validating the action name" do
    [nil, '', 'foo bar', '-foobar'].each do |input|
      it "should treat #{input.inspect} as an invalid name" do
        expect { Puppet::Interface::Action.new(nil, input) }.
          should raise_error(/is an invalid action name/)
      end
    end
  end

  describe "when invoking" do
    it "should be able to call other actions on the same object" do
      string = Puppet::String.new(:my_string, '0.0.1') do
        action(:foo) do
          invoke { 25 }
        end

        action(:bar) do
          invoke { "the value of foo is '#{foo}'" }
        end
      end
      string.foo.should == 25
      string.bar.should == "the value of foo is '25'"
    end

    # bar is a class action calling a class action
    # quux is a class action calling an instance action
    # baz is an instance action calling a class action
    # qux is an instance action calling an instance action
    it "should be able to call other actions on the same object when defined on a class" do
      class Puppet::String::MyStringBaseClass < Puppet::String
        action(:foo) do
          invoke { 25 }
        end

        action(:bar) do
          invoke { "the value of foo is '#{foo}'" }
        end

        action(:quux) do
          invoke { "qux told me #{qux}" }
        end
      end

      string = Puppet::String::MyStringBaseClass.new(:my_inherited_string, '0.0.1') do
        action(:baz) do
          invoke { "the value of foo in baz is '#{foo}'" }
        end

        action(:qux) do
          invoke { baz }
        end
      end
      string.foo.should  == 25
      string.bar.should  == "the value of foo is '25'"
      string.quux.should == "qux told me the value of foo in baz is '25'"
      string.baz.should  == "the value of foo in baz is '25'"
      string.qux.should  == "the value of foo in baz is '25'"
    end
  end
end
