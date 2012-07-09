require 'spec_helper'
require 'puppet/dsl/blank_slate'
require 'puppet/dsl/type_reference'

describe Puppet::DSL::BlankSlate do
  def evaluate(&block)
    Puppet::DSL::BlankSlate.new.instance_eval &block
  end

  it "should have only few methods defined" do
    # List of methods implemented in BasicObject in Ruby 1.9
    [:==, :equal?, :'!', :'!=',
      :instance_eval, :instance_exec,
      :__send__, :__id__].each do |m|
      lambda do
        Puppet::DSL::BlankSlate.new.__send__ m
      end.should_not raise_error NoMethodError
      end
  end

  it "should return a type reference when accessing constant" do
    evaluate do
      Puppet::DSL::BlankSlate::Notify # Full name needs to be used to trigger const_missing
    end.should be_a Puppet::DSL::TypeReference
  end

  it "should return a type reference using `type' method" do
    evaluate do
      type("notify")
    end.should be_a Puppet::DSL::TypeReference
  end

  it "should raise NameError when there is no valid type" do
    lambda do
      evaluate do
        Puppet::DSL::BlankSlate::Foobar
      end
    end.should raise_error NameError
  end


  it "should proxy `raise' calls to Object" do
    Object.expects :raise
    evaluate do
      raise 
    end
  end

  describe "private methods" do

    it "should be able to define singleton methods" do
      lambda do
        evaluate do
          define_singleton_method :foobarbaz do
            raise ::NameError
          end

          foobarbaz
        end
      end.should raise_error NameError
    end

  end

end

