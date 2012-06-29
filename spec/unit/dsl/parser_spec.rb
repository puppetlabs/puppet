require 'spec_helper'
require 'puppet_spec/dsl'
require 'puppet/dsl/parser'

describe Puppet::DSL::Parser do

  include PuppetSpec::DSL

  describe "scope" do
    it "should allow to access top scope" do
      scope = mock
      evaluate_in_scope scope do
        Puppet::DSL::Parser.top_scope.should == scope
      end
    end

    it "should allow to access current scope" do
      scope = mock
      evaluate_in_scope scope do
        Puppet::DSL::Parser.current_scope.should == scope
      end
    end

    it "should fail when trying to remove scope from empty stack" do
      lambda do
        Puppet::DSL::Parser.remove_scope
      end.should raise_error RuntimeError
    end
  end

  describe "#evaluate" do
    it "should set ruby_code for main object" do
      main = mock
      main.expects :'ruby_code='

      Puppet::DSL::Parser.new(main, proc {}).evaluate
    end
  end

  describe "#valid_nesting?" do
    it "should return true when in top level scope" do
      evaluate_in_scope mock do
        Puppet::DSL::Parser.valid_nesting?.should be_equal true
      end
    end

    it "should return false when not in top level scope" do
      evaluate_in_scope mock do
        evaluate_in_scope mock do
          Puppet::DSL::Parser.valid_nesting?.should be_equal false
        end
      end

    end
  end

end

