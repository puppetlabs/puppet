require 'spec_helper'
require 'puppet_spec/dsl'
require 'puppet/dsl/parser'
include PuppetSpec::DSL

describe Puppet::DSL::Parser do
  prepare_compiler_and_scope_for_evaluation

  describe "scope" do
    it "should allow to access current scope" do
      scope = mock
      scope.stubs(:known_resource_types)
      evaluate_in_scope :scope => scope do
        Puppet::DSL::Parser.current_scope.should be scope
      end
    end

    it "should fail when trying to remove scope from empty stack" do
      lambda do
        Puppet::DSL::Parser.remove_scope
      end.should raise_error RuntimeError
    end

    it "allows to add and remove a scope" do
      scope = mock
      Puppet::DSL::Parser.add_scope scope
      Puppet::DSL::Parser.current_scope.should be scope
      Puppet::DSL::Parser.remove_scope
      Puppet::DSL::Parser.current_scope.should be nil
    end
  end

  describe "#evaluate" do
    let(:filename)  { "testfile" }
    let(:string)    { "test" }
    let(:ruby_code) { Array.new   }
    let(:main)      { mock "main" }
    subject         { Puppet::DSL::Parser }

    it "sets ruby_code for main object" do
      main.expects(:ruby_code).returns ruby_code
      subject.prepare_for_evaluation main, string, filename
      ruby_code.count.should == 1
    end

    it "sets parsed file's filename for ruby dsl" do
      main.stubs(:ruby_code).returns ruby_code
      subject.prepare_for_evaluation main, string, filename

      ruby_code.first.inspect.should == filename.inspect
    end

  end

end

