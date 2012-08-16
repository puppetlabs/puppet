require 'spec_helper'
require 'puppet_spec/dsl'
require 'puppet/dsl/type_reference'

describe Puppet::DSL::TypeReference do

  include PuppetSpec::DSL

  before :each do
    prepare_compiler_and_scope
  end

  describe "#initialize" do

    it "should return a type reference" do
      Puppet::DSL::Context.stubs(:const_defined?).returns true

      Puppet::DSL::TypeReference.new("name").should_not be nil
    end

    it "should check whether the type exists" do
      Puppet::DSL::Context.expects(:const_defined?).returns true

      lambda do
        Puppet::DSL::TypeReference.new "name"
      end.should_not raise_error NameError
    end

    it "should raise NameError when the type doesn't exist" do
      Puppet::DSL::Context.expects(:const_defined?).returns false
      lambda do
        Puppet::DSL::TypeReference.new "name"
      end.should raise_error NameError
    end

    it "should canonize type name" do
      Puppet::DSL::Context.stubs(:const_defined?).returns true
      Puppet::DSL::TypeReference.any_instance.expects(:canonize_type).with("name").returns "Name"

      Puppet::DSL::TypeReference.new "name"
    end

  end

  describe "#[]" do
    before :each do
      @reference = Puppet::DSL::TypeReference.new "notify"
    end

    it "should return new ResourceReference instance" do
      evaluate_in_context do
        notify "test"
      end

      evaluate_in_scope @scope do
        @reference["test"].should be_a Puppet::DSL::ResourceReference
      end
    end

    it "should raise ArgumentError when the resource doesn't exist" do
      evaluate_in_scope @scope do
        lambda do
          @reference["asdf"]
        end.should raise_error ArgumentError
      end
    end

    it "should cache created references" do
      evaluate_in_context do
        notify "test"
      end

      evaluate_in_scope @scope do
        resource = @reference["test"]
        resource.object_id.should be_equal @reference["test"].object_id
      end
    end

  end

  describe "#collect" do
    it "should create a new exported collection" do
      evaluate_in_context do
        Puppet::DSL::Context::Notify.collect
      end
      @compiler.collections.map do |c|
        [c.type, c.form]
      end.should include ["Notify", :exported]
    end

    it "should return the created collection" do
      evaluate_in_context do
        Puppet::DSL::Context::Notify.collect
      end.should be_a Puppet::Parser::Collector
    end

  end

  describe "#realize" do
    it "should create a new virtual collection" do
      evaluate_in_context do
        Puppet::DSL::Context::Notify.realize
      end
      @compiler.collections.map do |c|
        [c.type, c.form]
      end.should include ["Notify", :virtual]
    end

    it "should return the created collection" do
      evaluate_in_context do
        Puppet::DSL::Context::Notify.realize
      end.should be_a Puppet::Parser::Collector
    end

  end

  describe "#defaults" do

    it "should apply defaults for a type" do
      evaluate_in_context do
        Puppet::DSL::Context::Notify.defaults :message => 42
      end
      @scope.lookupdefaults("Notify").should have_key :message
    end

    it "should return current defaults" do
      evaluate_in_context do
        Puppet::DSL::Context::Notify.defaults :message => 42
      end.should == {:message => 42}
    end

    it "should return current defaults when called without arguments" do
      evaluate_in_context do
        Puppet::DSL::Context::Notify.defaults :message => 42
        Puppet::DSL::Context::Notify.defaults
      end.should == {:message => 42}
    end

    it "should allow to pass a hash" do
      lambda do
        evaluate_in_context do
          Puppet::DSL::Context::Notify.defaults :message => 42
        end
      end.should_not raise_error
    end

    it "should allow to pass a block" do
      lambda do
        evaluate_in_context do
          Puppet::DSL::Context::Notify.defaults do |d|
            d.message = 42
          end
        end
      end.should_not raise_error
    end

    it "should allow passing both hash and block; block overwrites hash" do
      lambda do
        evaluate_in_context do
          Puppet::DSL::Context::Notify.defaults :message => 30 do |d|
            d.message = 42
          end
        end.should == {:message => '42'}
      end.should_not raise_error

    end

  end


end

