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
    let(:file) { StringIO.new "test" }
    let(:main) { mock "main"         }
    subject    { Puppet::DSL::Parser }

    it "sets ruby_code for main object" do
      main.expects(:ruby_code).returns Array.new

      subject.prepare_for_evaluation main, file
    end

    it "reads the contents of IO object" do
      main.stubs(:ruby_code).returns Array.new

      subject.prepare_for_evaluation main, file
    end

    it "calls #path on io when it responds to it" do
      main.stubs(:ruby_code).returns Array.new
      file.expects(:path).returns nil

      subject.prepare_for_evaluation main, file
    end

  end

end

