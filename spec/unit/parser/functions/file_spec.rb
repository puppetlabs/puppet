#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'

describe "the 'file' function" do
  include PuppetSpec::Files

  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  it "should exist" do
    Puppet::Parser::Functions.function("file").should == "function_file"
  end

  def with_file_content(content)
    path = tmpfile('file-function')
    file = File.new(path, 'w')
    file.sync = true
    file.print content
    yield path
  end

  it "should read a file" do
    with_file_content('file content') do |name|
      scope.function_file([name]).should == "file content"
    end
  end

  it "should read a file from a module path" do
    mod = mock 'module'
    mod.expects(:file).with('myfile').returns('/one/mymod/files/myfile')
    environment.expects(:module).with('mymod').returns(mod)
    Puppet::FileSystem.expects(:exist?).with("/one/mymod/files/myfile").returns true
    File.stubs(:read).with('/one/mymod/files/myfile').returns('file content')

    scope.function_file(['mymod/myfile']).should == 'file content'
  end

  it "should return the first file if given two files" do
    context "with absolute paths" do
      with_file_content('one') do |one|
        with_file_content('two') do |two|
          scope.function_file([one, two]).should == "one"
        end
      end
    end

    context "with module paths" do
      mod = mock 'module'
      environment.expects(:module).with('mymod').returns(mod)
      mod.expects(:file).with('first').returns('/one/mymod/files/first')
      mod.expects(:file).with('second').returns('/one/mymod/files/second')
      Puppet::FileSystem.expects(:exist?).with("/one/mymod/files/first").returns(true)
      Puppet::FileSystem.expects(:exist?).with("/one/mymod/files/second").returns(true)
      File.stubs(:read).with('/one/mymod/files/second').returns('first')
      File.stubs(:read).with('/one/mymod/files/second').returns('second')

      scope.function_file(['mymod/myfile']).should == 'file content'
    end

    context "with mixed paths, absolute first" do
      with_file_content('absolute') do |absolute|
        mod = mock 'module'
        environment.expects(:module).with('mymod').returns(mod)
        mod.expects(:file).with('module').returns('/one/mymod/files/module')
        Puppet::FileSystem.expects(:exist?).with("/one/mymod/files/module").returns true
        File.stubs(:read).with('/one/mymod/files/module').returns('module')

        scope.function_file([absolute,'mymod/module']).should == 'absolute'
      end
    end

    context "with mixed paths, module first" do
      with_file_content('one') do |absolute|
        mod = mock 'module'
        environment.expects(:module).with('mymod').returns(mod)
        mod.expects(:file).with('module').returns('/one/mymod/files/module')
        Puppet::FileSystem.expects(:exist?).with("/one/mymod/files/module").returns true
        File.stubs(:read).with('/one/mymod/files/module').returns('module')

        scope.function_file(['mymod/module',absolute]).should == 'module'
      end
    end
  end

  it "should not fail when some files are absent" do
    expect {
      with_file_content('one') do |one|
        scope.function_file([make_absolute("/should-not-exist"), one]).should == 'one'
      end
    }.to_not raise_error
  end

  it "should fail when all files are absent" do
    expect {
      scope.function_file([File.expand_path('one')])
    }.to raise_error(Puppet::ParseError, /Could not find any files/)
  end
end
