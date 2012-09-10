require 'spec_helper'
require 'puppet_spec/dsl'
require 'puppet/dsl/parser'

describe Puppet::DSL::Parser do
  include PuppetSpec::DSL


  describe "scope" do
    it "should allow to access current scope" do
      scope = mock
      evaluate_in_scope scope do
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

    # before(:each) { file.rewind }

    it "sets ruby_code for main object" do
      main.expects :'ruby_code='

      subject.evaluate main, file
    end

    it "reads the contents of IO object" do
      main.stubs :'ruby_code='

      subject.evaluate main, file
    end

    it "calls #path on io when it responds to it" do
      main.stubs :'ruby_code='
      file.expects(:path).returns nil

      subject.evaluate main, file
    end

    it "raises an exception when io doesn't respond to read" do
      lambda { subject.evaluate main, nil }.should raise_error ArgumentError
    end
  end

end

