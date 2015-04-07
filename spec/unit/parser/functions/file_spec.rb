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

  def with_file_content(content)
    path = tmpfile('file-function')
    file = File.new(path, 'wb')
    file.sync = true
    file.print content
    yield path
  end

  it "should read a file" do
    with_file_content('file content') do |name|
      expect(scope.function_file([name])).to eq("file content")
    end
  end

  it "should read a file keeping line endings intact" do
    with_file_content("file content\r\n") do |name|
      expect(scope.function_file([name])).to eq("file content\r\n")
    end
  end

  it "should read a file from a module path" do
    with_file_content('file content') do |name|
      mod = mock 'module'
      mod.stubs(:file).with('myfile').returns(name)
      compiler.environment.stubs(:module).with('mymod').returns(mod)

      expect(scope.function_file(['mymod/myfile'])).to eq('file content')
    end
  end

  it "should return the first file if given two files with absolute paths" do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        expect(scope.function_file([one, two])).to eq("one")
      end
    end
  end

  it "should return the first file if given two files with module paths" do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        mod = mock 'module'
        compiler.environment.expects(:module).with('mymod').returns(mod)
        mod.expects(:file).with('one').returns(one)
        mod.stubs(:file).with('two').returns(two)

        expect(scope.function_file(['mymod/one','mymod/two'])).to eq('one')
      end
    end
  end

  it "should return the first file if given two files with mixed paths, absolute first" do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        mod = mock 'module'
        compiler.environment.stubs(:module).with('mymod').returns(mod)
        mod.stubs(:file).with('two').returns(two)

        expect(scope.function_file([one,'mymod/two'])).to eq('one')
      end
    end
  end

  it "should return the first file if given two files with mixed paths, module first" do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        mod = mock 'module'
        compiler.environment.expects(:module).with('mymod').returns(mod)
        mod.stubs(:file).with('two').returns(two)

        expect(scope.function_file(['mymod/two',one])).to eq('two')
      end
    end
  end

  it "should not fail when some files are absent" do
    expect {
      with_file_content('one') do |one|
        expect(scope.function_file([make_absolute("/should-not-exist"), one])).to eq('one')
      end
    }.to_not raise_error
  end

  it "should fail when all files are absent" do
    expect {
      scope.function_file([File.expand_path('one')])
    }.to raise_error(Puppet::ParseError, /Could not find any files/)
  end
end
