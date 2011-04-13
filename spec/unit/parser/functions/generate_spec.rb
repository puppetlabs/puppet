#!/usr/bin/env rspec
require 'spec_helper'

describe "the generate function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should exist" do
    Puppet::Parser::Functions.function("generate").should == "function_generate"
  end

  it "should accept a fully-qualified path as a command" do
    command = File::SEPARATOR + "command"
    Puppet::Util.expects(:execute).with([command]).returns("yay")
    lambda { @scope.function_generate([command]) }.should_not raise_error(Puppet::ParseError)
  end

  it "should not accept a relative path as a command" do
    command = "command"
    lambda { @scope.function_generate([command]) }.should raise_error(Puppet::ParseError)
  end

  # Really not sure how to implement this test, just sure it needs
  # to be implemented.
  it "should not accept a command containing illegal characters"

  it "should not accept a command containing '..'" do
    command = File::SEPARATOR + "command#{File::SEPARATOR}..#{File::SEPARATOR}"
    lambda { @scope.function_generate([command]) }.should raise_error(Puppet::ParseError)
  end

  it "should execute the generate script with the correct working directory" do
    command = File::SEPARATOR + "command"
    Dir.expects(:chdir).with(File.dirname(command)).yields
    Puppet::Util.expects(:execute).with([command]).returns("yay")
    lambda { @scope.function_generate([command]) }.should_not raise_error(Puppet::ParseError)
  end
end
