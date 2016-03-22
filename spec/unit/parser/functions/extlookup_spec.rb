#! /usr/bin/env ruby
require 'spec_helper'

describe "the extlookup function" do
  include PuppetSpec::Files

  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it "should exist" do
    Puppet::Parser::Functions.function("extlookup").should == "function_extlookup"
  end

  it "should raise an ArgumentError if there is less than 1 arguments" do
    lambda { @scope.function_extlookup([]) }.should( raise_error(ArgumentError))
  end

  it "should raise an ArgumentError if there is more than 3 arguments" do
    lambda { @scope.function_extlookup(["foo", "bar", "baz", "gazonk"]) }.should( raise_error(ArgumentError))
  end

  it "should return the default" do
    result = @scope.function_extlookup([ "key", "default"])
    result.should == "default"
  end

  it "should lookup the key in a supplied datafile" do
    dir = tmpdir("extlookup_spec")
    File.open("#{dir}/extlookup.csv", "w") do |t|
      t.puts 'key,value'
      t.puts 'nonkey,nonvalue'
    end

    @scope.stubs(:[]).with('::extlookup_datadir').returns(dir)
    @scope.stubs(:[]).with('::extlookup_precedence').returns(nil)
    result = @scope.function_extlookup([ "key", "default", "extlookup"])
    result.should == "value"
  end

  it "should return an array if the datafile contains more than two columns" do
    dir = tmpdir("extlookup_spec")
    File.open("#{dir}/extlookup.csv", "w") do |t|
      t.puts 'key,value1,value2'
      t.puts 'nonkey,nonvalue,nonvalue'
    end

    @scope.stubs(:[]).with('::extlookup_datadir').returns(dir)
    @scope.stubs(:[]).with('::extlookup_precedence').returns(nil)
    result = @scope.function_extlookup([ "key", "default", "extlookup"])
    result.should == ["value1", "value2"]
  end

  it "should raise an error if there's no matching key and no default" do
    dir = tmpdir("extlookup_spec")
    File.open("#{dir}/extlookup.csv", "w") do |t|
      t.puts 'nonkey,nonvalue'
    end

    @scope.stubs(:[]).with('::extlookup_datadir').returns(dir)
    @scope.stubs(:[]).with('::extlookup_precedence').returns(nil)
    lambda { @scope.function_extlookup([ "key", nil, "extlookup"]) }.should raise_error(Puppet::ParseError, /No match found.*key/)
  end

  describe "should look in $extlookup_datadir for data files listed by $extlookup_precedence" do
    before do
      dir = tmpdir('extlookup_datadir')
      @scope.stubs(:[]).with('::extlookup_datadir').returns(dir)
      File.open(File.join(dir, "one.csv"),"w"){|one| one.puts "key,value1" }
      File.open(File.join(dir, "two.csv"),"w") do |two|
        two.puts "key,value2"
        two.puts "key2,value_two"
      end
    end

    it "when the key is in the first file" do
      @scope.stubs(:[]).with('::extlookup_precedence').returns(["one","two"])
      result = @scope.function_extlookup([ "key" ])
      result.should == "value1"
    end

    it "when the key is in the second file" do
      @scope.stubs(:[]).with('::extlookup_precedence').returns(["one","two"])
      result = @scope.function_extlookup([ "key2" ])
      result.should == "value_two"
    end

    it "should not modify extlookup_precedence data" do
      variable = '%{fqdn}'
      @scope.stubs(:[]).with('::extlookup_precedence').returns([variable,"one"])
      @scope.stubs(:[]).with('::fqdn').returns('myfqdn')
      result = @scope.function_extlookup([ "key" ])
      variable.should == '%{fqdn}'
    end
  end
end
