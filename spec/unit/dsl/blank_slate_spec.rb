require 'spec_helper'
require 'puppet/dsl/blank_slate'

describe Puppet::DSL::BlankSlate do

  it "should have only few methods defined" do
    # List of methods implemented in BasicObject in Ruby 1.9
    [:==, :equal?, :instance_eval, :instance_exec, :__send__, :__id__].each do |m|
      lambda do
        Puppet::DSL::BlankSlate.new.__send__ m
      end.should_not raise_error NoMethodError
      end
  end

  describe "private methods" do

    it "should be able to define singleton methods" do
      lambda do
          Puppet::DSL::BlankSlate.new.__send__ :define_singleton_method, :foobarbaz do
            raise ::NameError
          end.foobarbaz
      end.should raise_error NameError
    end
  end

end

