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

  it "should return the first file if given two files" do
    with_file_content('one') do |one|
      with_file_content('two') do |two|
        scope.function_file([one, two]).should == "one"
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
