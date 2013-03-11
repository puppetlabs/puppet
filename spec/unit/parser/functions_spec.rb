#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::Functions do
  def callable_functions_from(mod)
    Class.new { include mod }.new
  end

  it "should have a method for returning an environment-specific module" do
    Puppet::Parser::Functions.environment_module(Puppet::Node::Environment.new("myenv")).should be_instance_of(Module)
  end

  it "should use the current default environment if no environment is provided" do
    Puppet::Parser::Functions.environment_module.should be_instance_of(Module)
  end

  it "should be able to retrieve environment modules asked for by name rather than instance" do
    Puppet::Parser::Functions.environment_module(Puppet::Node::Environment.new("myenv")).should equal(Puppet::Parser::Functions.environment_module("myenv"))
  end

  describe "when calling newfunction" do
    let(:function_module) { Module.new }
    before do
      Puppet::Parser::Functions.stubs(:environment_module).returns(function_module)
    end

    it "should create the function in the environment module" do
      Puppet::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }

      function_module.should be_method_defined :function_name
    end

    it "should warn if the function already exists" do
      Puppet::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }
      Puppet.expects(:warning)

      Puppet::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }
    end

    it "should raise an error if the function type is not correct" do
      lambda { Puppet::Parser::Functions.newfunction("name", :type => :unknown) { |args| } }.should raise_error Puppet::DevError, "Invalid statement type :unknown"
    end

    it "instruments the function to profiles the execution" do
      messages = []
      Puppet::Util::Profiler.current = Puppet::Util::Profiler::WallClock.new(proc { |msg| messages << msg }, "id")

      Puppet::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }
      callable_functions_from(function_module).function_name([])

      messages.first.should =~ /Called name/
    end
  end

  describe "when calling function to test function existence" do
    let(:function_module) { Module.new }
    before do
      Puppet::Parser::Functions.stubs(:environment_module).returns(function_module)
    end

    it "should return false if the function doesn't exist" do
      Puppet::Parser::Functions.autoloader.stubs(:load)

      Puppet::Parser::Functions.function("name").should be_false
    end

    it "should return its name if the function exists" do
      Puppet::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }

      Puppet::Parser::Functions.function("name").should == "function_name"
    end

    it "should try to autoload the function if it doesn't exist yet" do
      Puppet::Parser::Functions.autoloader.expects(:load)

      Puppet::Parser::Functions.function("name")
    end
  end

  describe "when calling function to test arity" do
    let(:function_module) { Module.new }
    before do
      Puppet::Parser::Functions.stubs(:environment_module).returns(function_module)
    end

    it "should raise an error if the function is called with too many arguments" do
      Puppet::Parser::Functions.newfunction("name", :arity => 2) { |args| }
      lambda { callable_functions_from(function_module).function_name([1,2,3]) }.should raise_error ArgumentError
    end

    it "should raise an error if the function is called with too few arguments" do
      Puppet::Parser::Functions.newfunction("name", :arity => 2) { |args| }
      lambda { callable_functions_from(function_module).function_name([1]) }.should raise_error ArgumentError
    end

    it "should not raise an error if the function is called with correct number of arguments" do
      Puppet::Parser::Functions.newfunction("name", :arity => 2) { |args| }
      lambda { callable_functions_from(function_module).function_name([1,2]) }.should_not raise_error ArgumentError
    end

    it "should raise an error if the variable arg function is called with too few arguments" do
      Puppet::Parser::Functions.newfunction("name", :arity => -3) { |args| }
      lambda { callable_functions_from(function_module).function_name([1]) }.should raise_error ArgumentError
    end

    it "should not raise an error if the variable arg function is called with correct number of arguments" do
      Puppet::Parser::Functions.newfunction("name", :arity => -3) { |args| }
      lambda { callable_functions_from(function_module).function_name([1,2]) }.should_not raise_error ArgumentError
    end

    it "should not raise an error if the variable arg function is called with more number of arguments" do
      Puppet::Parser::Functions.newfunction("name", :arity => -3) { |args| }
      lambda { callable_functions_from(function_module).function_name([1,2,3]) }.should_not raise_error ArgumentError
    end
  end

  describe "::arity" do
    it "returns the given arity of a function" do
      Puppet::Parser::Functions.newfunction("name", :arity => 4) { |args| }
      Puppet::Parser::Functions.arity(:name).should == 4
    end

    it "returns -1 if no arity is given" do
      Puppet::Parser::Functions.newfunction("name") { |args| }
      Puppet::Parser::Functions.arity(:name).should == -1
    end
  end

  describe "::get_function" do
    it "can retrieve a function defined on the *root* environment" do
      Thread.current[:environment] = nil
      function = Puppet::Parser::Functions.newfunction("atest", :type => :rvalue) do
        nil
      end

      Puppet::Node::Environment.current = "test_env"
      Puppet::Parser::Functions.send(:get_function, "atest").should equal(function)
    end

    it "can retrieve a function from the current environment" do
      Puppet::Node::Environment.current = "test_env"
      function = Puppet::Parser::Functions.newfunction("atest", :type => :rvalue) do
        nil
      end

      Puppet::Parser::Functions.send(:get_function, "atest").should equal(function)
    end

    it "takes a function in the current environment over one in the root" do
      root = Puppet::Node::Environment.root
      env = Puppet::Node::Environment.current = "test_env"
      func1 = {:type => :rvalue, :name => :testfunc, :extra => :func1}
      func2 = {:type => :rvalue, :name => :testfunc, :extra => :func2}
      Puppet::Parser::Functions.instance_eval do
        @functions[Puppet::Node::Environment.root][:atest] = func1
        @functions[Puppet::Node::Environment.current][:atest] = func2
      end

      Puppet::Parser::Functions.send(:get_function, "atest").should equal(func2)
    end
  end

  describe "::merged_functions" do
    it "returns functions in both the current and root environment" do
      Thread.current[:environment] = nil
      func_a = Puppet::Parser::Functions.newfunction("test_a", :type => :rvalue) do
        nil
      end
      Puppet::Node::Environment.current = "test_env"
      func_b = Puppet::Parser::Functions.newfunction("test_b", :type => :rvalue) do
        nil
      end

      Puppet::Parser::Functions.send(:merged_functions).should include(:test_a, :test_b)
    end

    it "returns functions from the current environment over the root environment" do
      root = Puppet::Node::Environment.root
      env = Puppet::Node::Environment.current = "test_env"
      func1 = {:type => :rvalue, :name => :testfunc, :extra => :func1}
      func2 = {:type => :rvalue, :name => :testfunc, :extra => :func2}
      Puppet::Parser::Functions.instance_eval do
        @functions[Puppet::Node::Environment.root][:atest] = func1
        @functions[Puppet::Node::Environment.current][:atest] = func2
      end

      Puppet::Parser::Functions.send(:merged_functions)[:atest].should equal(func2)
    end
  end

  describe "::add_function" do
    it "adds functions to the current environment" do
      func = {:type => :rvalue, :name => :testfunc}
      Puppet::Node::Environment.current = "add_function_test"
      Puppet::Parser::Functions.send(:add_function, :testfunc, func)

      Puppet::Parser::Functions.instance_variable_get(:@functions)[Puppet::Node::Environment.root].should_not include(:testfunc)
      Puppet::Parser::Functions.instance_variable_get(:@functions)[Puppet::Node::Environment.current].should include(:testfunc)
    end
  end
end
