require 'spec_helper'
require 'puppet/resource'
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

  context "when accessing" do
    before :each do
      @resource = mock
    end

    describe "getting" do
      it "should proxy messages to a resource" do
        @resource.expects(:[]).with(:param).returns 42

        Puppet::DSL::ResourceDecorator.new @resource do |r|
          r.param.should == 42
        end
      end


      it "should cache methods for future use" do
        @resource.expects(:[]).twice.with(:foobar).returns 42

        Puppet::DSL::ResourceDecorator.new @resource do |r|
          r.foobar.should == 42
          r.foobar.should == 42
        end
      end
    end

    describe "setting" do
      it "should proxy get messages to a resource "do
        @resource.expects(:[]=).with(:param, 42)

        Puppet::DSL::ResourceDecorator.new @resource do |r|
          r.param = 42
        end
      end

      it "should call `reference' on resource references" do
        prepare_compiler_and_scope
        evaluate_in_context { notify "bar" }

        @resource.expects(:[]=).with :param, "Notify[bar]"
        ref = evaluate_in_context { Puppet::DSL::Context::Notify["bar"] }
        Puppet::DSL::ResourceDecorator.new @resource do |r|
          r.param = ref
        end
      end

      it "should cache methods for future use" do
        @resource.expects(:[]=).twice.with :foobar, 42

        Puppet::DSL::ResourceDecorator.new @resource do |r|
          r.foobar = 42
          r.foobar = 42
        end
      end

    end
  end

end

