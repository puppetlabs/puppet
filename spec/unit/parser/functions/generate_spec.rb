#! /usr/bin/env ruby
require 'spec_helper'

describe "the generate function" do
  include PuppetSpec::Files

  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  it "should exist" do
    expect(Puppet::Parser::Functions.function("generate")).to eq("function_generate")
  end

  it "accept a fully-qualified path as a command" do
    command = File.expand_path('/command/foo')
    Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
    expect(scope.function_generate([command])).to eq("yay")
  end

  it "should not accept a relative path as a command" do
    expect { scope.function_generate(["command"]) }.to raise_error(Puppet::ParseError)
  end

  it "should not accept a command containing illegal characters" do
    expect { scope.function_generate([File.expand_path('/##/command')]) }.to raise_error(Puppet::ParseError)
  end

  it "should not accept a command containing spaces" do
    expect { scope.function_generate([File.expand_path('/com mand')]) }.to raise_error(Puppet::ParseError)
  end

  it "should not accept a command containing '..'" do
    command = File.expand_path("/command/../")
    expect { scope.function_generate([command]) }.to raise_error(Puppet::ParseError)
  end

  it "should execute the generate script with the correct working directory" do
    command = File.expand_path("/command")
    Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
    expect(scope.function_generate([command])).to eq('yay')
  end

  describe "on Windows", :if => Puppet.features.microsoft_windows? do
    it "should accept the tilde in the path" do
      command = "C:/DOCUME~1/ADMINI~1/foo.bat"
      Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
      expect(scope.function_generate([command])).to eq('yay')
    end

    it "should accept lower-case drive letters" do
      command = 'd:/command/foo'
      Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
      expect(scope.function_generate([command])).to eq('yay')
    end

    it "should accept upper-case drive letters" do
      command = 'D:/command/foo'
      Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
      expect(scope.function_generate([command])).to eq('yay')
    end

    it "should accept forward and backslashes in the path" do
      command = 'D:\command/foo\bar'
      Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
      expect(scope.function_generate([command])).to eq('yay')
    end

    it "should reject colons when not part of the drive letter" do
      expect { scope.function_generate(['C:/com:mand']) }.to raise_error(Puppet::ParseError)
    end

    it "should reject root drives" do
      expect { scope.function_generate(['C:/']) }.to raise_error(Puppet::ParseError)
    end
  end

  describe "on POSIX", :if => Puppet.features.posix? do
    it "should reject backslashes" do
      expect { scope.function_generate(['/com\\mand']) }.to raise_error(Puppet::ParseError)
    end

    it "should accept plus and dash" do
      command = "/var/folders/9z/9zXImgchH8CZJh6SgiqS2U+++TM/-Tmp-/foo"
      Dir.expects(:chdir).with(File.dirname(command)).returns("yay")
      expect(scope.function_generate([command])).to eq('yay')
    end
  end

  let :command do
    script_containing('function_generate',
      :windows => '@echo off' + "\n" + 'echo a-%1 b-%2',
      :posix   => '#!/bin/sh' + "\n" + 'echo a-$1 b-$2')
  end

  after :each do
    File.delete(command) if Puppet::FileSystem.exist?(command)
  end

  it "returns the output as a String" do
    expect(scope.function_generate([command]).class).to eq(String)
  end

  it "should call generator with no arguments" do
    expect(scope.function_generate([command])).to eq("a- b-\n")
  end

  it "should call generator with one argument" do
    expect(scope.function_generate([command, 'one'])).to eq("a-one b-\n")
  end

  it "should call generator with wo arguments" do
    expect(scope.function_generate([command, 'one', 'two'])).to eq("a-one b-two\n")
  end

  it "should fail if generator is not absolute" do
    expect { scope.function_generate(['boo']) }.to raise_error(Puppet::ParseError)
  end

  it "should fail if generator fails" do
    expect { scope.function_generate(['/boo']) }.to raise_error(Puppet::ParseError)
  end
end
