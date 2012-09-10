require 'spec_helper'
require 'puppet/parser/null_scope'

describe Puppet::Parser::NullScope do
  let(:collection) { mock "known_resource_types"              }
  subject          { Puppet::Parser::NullScope.new collection }


  it "always returns true when called #nil?" do
    subject.nil?.should be true
  end

  it "always returns self when undefined method is called" do
    [:each, :all, :split, :to_s].each do |m|
      subject.send(m).should be subject
    end
  end

  it "responds to #known_resource_types" do
    subject.respond_to?(:known_resource_types).should be true
    subject.known_resource_types.should == collection
  end

  it "responds to any method" do
    subject.respond_to?(:asdf).should be true
  end

  it "returns any method when called #method" do
    lambda { subject.method(:asdf) }.should_not raise_error
  end

  it "defines #respond_to_missing?" do
    subject.respond_to_missing?(:asdf).should be true
  end

end

