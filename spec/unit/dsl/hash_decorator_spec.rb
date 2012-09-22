require 'spec_helper'
require 'puppet_spec/dsl'
require 'puppet/resource'
require 'puppet/dsl/hash_decorator'

include PuppetSpec::DSL

describe Puppet::DSL::HashDecorator do
  it "should yield resource proxy to a block" do
    Puppet::DSL::HashDecorator.new mock do |r|
      # there is no way to test whether r is a HashDecorator instance due to
      # BlankSlate class nature, so I only test that something is yielded to
      # a block
      expect {r}.not_to be_nil
    end
  end

  context "when accessing" do
    let(:resource) { mock "Resource" }

    describe "getting" do
      it "should proxy messages to a resource" do
        resource.expects(:[]).with(:param).returns 42

        Puppet::DSL::HashDecorator.new resource do |r|
          r.param.should == 42
        end
      end


      it "should cache methods for future use" do
        resource.expects(:[]).twice.with(:foobar).returns 42

        Puppet::DSL::HashDecorator.new resource do |r|
          r.foobar.should == 42
          r.foobar.should == 42
        end
      end
    end

    describe "setting" do
      prepare_compiler_and_scope_for_evaluation
      it "should proxy get messages to a resource" do
        resource.expects(:[]=).with :param, '42'

        Puppet::DSL::HashDecorator.new resource do |r|
          r.param = 42
        end
      end

      it "should call `reference' on resource references" do
        evaluate_in_context { notify "bar" }

        resource.expects(:[]=).with :param, "Notify[bar]"
        ref = evaluate_in_context { Puppet::DSL::Context::Notify["bar"] }
        Puppet::DSL::HashDecorator.new resource do |r|
          r.param = ref
        end
      end

      it "should cache methods for future use" do
        resource.expects(:[]=).twice.with :foobar, '42'

        Puppet::DSL::HashDecorator.new resource do |r|
          r.foobar = 42
          r.foobar = 42
        end
      end

      it "doesn't convert values to string when resource is given" do
        value = Puppet::Parser::Resource.new "test", "whatever", {:scope => scope}
        value.expects(:to_s).never
        resource.expects(:[]=)

        Puppet::DSL::HashDecorator.new resource do |r|
          r.key = value
        end
      end

      it "converts values to string when unless resource is given" do
        value = mock
        value.expects :to_s
        resource.expects :[]=

        Puppet::DSL::HashDecorator.new resource do |r|
          r.foo = value
        end
      end

    end
  end

end

