require 'spec_helper'
require 'puppet/dsl/resource_decorator'

describe Puppet::DSL::ResourceDecorator do
  it "should yield resource proxy to a block" do
    Puppet::DSL::ResourceDecorator.new mock do |r|
      # there is no way to test whether r is a ResourceDecorator instance due to
      # BlankSlate class nature, so I only test that something is yielded to
      # a block
      expect {r}.not_to be_nil
    end
  end

  it "should raise an exception when passing invalid parameter" do
    resource = mock
    resource.expects(:valid_parameter?).with(:param).returns false

    lambda do
      Puppet::DSL::ResourceDecorator.new(resource) { |r| r.param }
    end.should raise_error
  end

  context "when accessing" do
    before :each do
      @resource = mock
      @resource.expects(:valid_parameter?).with(:param).returns true
    end

    it "should proxy set messages to a resource" do
      @resource.expects(:[]).once.with(:param).returns 42

      Puppet::DSL::ResourceDecorator.new @resource do |r|
        r.param.should == 42
      end
    end

    it "should proxy get messages to a resource "do
      @resource.expects(:[]=).once.with(:param, "42")

      Puppet::DSL::ResourceDecorator.new @resource do |r|
        r.param = 42
      end
    end
  end

end

