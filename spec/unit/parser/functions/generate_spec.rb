#!/usr/bin/env rspec
require 'spec_helper'

describe "the generate function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  let(:scope) { Puppet::Parser::Scope.new }

  it "should exist" do
    Puppet::Parser::Functions.function("generate").should == "function_generate"
  end

  it " accept a fully-qualified path as a command" do
    command = File.expand_path('/command/foo')
    Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
    scope.function_generate([command]).should == "yay"
  end

  it "should not accept a relative path as a command" do
    lambda { scope.function_generate(["command"]) }.should raise_error(Puppet::ParseError)
  end

  it "should not accept a command containing illegal characters" do
    lambda { scope.function_generate([File.expand_path('/##/command')]) }.should raise_error(Puppet::ParseError)
  end

  it "should not accept a command containing spaces" do
    lambda { scope.function_generate([File.expand_path('/com mand')]) }.should raise_error(Puppet::ParseError)
  end

  it "should not accept a command containing '..'" do
    command = File.expand_path("/command/../")
    lambda { scope.function_generate([command]) }.should raise_error(Puppet::ParseError)
  end

  it "should execute the generate script with the correct working directory" do
    command = File.expand_path("/command")
    Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
    scope.function_generate([command]).should == 'yay'
  end

  describe "on Windows", :as_platform => :windows do
    it "should accept lower-case drive letters" do
      command = 'd:/command/foo'
      Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
      scope.function_generate([command]).should == 'yay'
    end

    it "should accept upper-case drive letters" do
      command = 'D:/command/foo'
      Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
      scope.function_generate([command]).should == 'yay'
    end

    it "should accept forward and backslashes in the path" do
      command = 'D:\command/foo\bar'
      Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
      scope.function_generate([command]).should == 'yay'
    end

    it "should reject colons when not part of the drive letter" do
      lambda { scope.function_generate(['C:/com:mand']) }.should raise_error(Puppet::ParseError)
    end

    it "should reject root drives" do
      lambda { scope.function_generate(['C:/']) }.should raise_error(Puppet::ParseError)
    end
  end

  describe "on non-Windows", :as_platform => :posix do
    it "should reject backslashes" do
      lambda { scope.function_generate(['/com\\mand']) }.should raise_error(Puppet::ParseError)
    end
  end
end
