#!/usr/bin/env rspec
require 'spec_helper'
require 'tempfile'

describe "the extlookup function" do
  include PuppetSpec::Files

  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @scope = Puppet::Parser::Scope.new
    @scope.stubs(:environment).returns(Puppet::Node::Environment.new('production'))
  end

  it "should exist" do
    Puppet::Parser::Functions.function("extlookup").should == "function_extlookup"
  end

  it "should raise a ParseError if there is less than 1 arguments" do
    lambda { @scope.function_extlookup([]) }.should( raise_error(Puppet::ParseError))
  end

  it "should raise a ParseError if there is more than 3 arguments" do
    lambda { @scope.function_extlookup(["foo", "bar", "baz", "gazonk"]) }.should( raise_error(Puppet::ParseError))
  end

  it "should return the default" do
    result = @scope.function_extlookup([ "key", "default"])
    result.should == "default"
  end

  it "should lookup the key in a supplied datafile" do
    t = Tempfile.new('extlookup.csv') do
      t.puts 'key,value'
      t.puts 'nonkey,nonvalue'
      t.close

      result = @scope.function_extlookup([ "key", "default", t.path])
      result.should == "value"
    end
  end

  it "should return an array if the datafile contains more than two columns" do
    t = Tempfile.new('extlookup.csv') do
      t.puts 'key,value1,value2'
      t.puts 'nonkey,nonvalue,nonvalue'
      t.close

      result = @scope.function_extlookup([ "key", "default", t.path])
      result.should == ["value1", "value2"]
    end
  end

  it "should raise an error if there's no matching key and no default" do
    t = Tempfile.new('extlookup.csv') do
      t.puts 'key,value'
      t.puts 'nonkey,nonvalue'
      t.close

      result = @scope.function_extlookup([ "key", nil, t.path])
      result.should == "value"
    end
  end

  describe "should look in $extlookup_datadir for data files listed by $extlookup_precedence" do
    before do
      dir = tmpdir('extlookup_datadir')
      @scope.stubs(:lookupvar).with('::extlookup_datadir').returns(dir)
      File.open(File.join(dir, "one.csv"),"w"){|one| one.puts "key,value1" }
      File.open(File.join(dir, "two.csv"),"w") do |two|
        two.puts "key,value2"
        two.puts "key2,value_two"
      end
    end

    it "when the key is in the first file" do
      @scope.stubs(:lookupvar).with('::extlookup_precedence').returns(["one","two"])
      result = @scope.function_extlookup([ "key" ])
      result.should == "value1"
    end

    it "when the key is in the second file" do
      @scope.stubs(:lookupvar).with('::extlookup_precedence').returns(["one","two"])
      result = @scope.function_extlookup([ "key2" ])
      result.should == "value_two"
    end

    it "should not modify extlookup_precedence data" do
      variable = '%{fqdn}'
      @scope.stubs(:lookupvar).with('::extlookup_precedence').returns([variable,"one"])
      @scope.stubs(:lookupvar).with('::fqdn').returns('myfqdn')
      result = @scope.function_extlookup([ "key" ])
      variable.should == '%{fqdn}'
    end
  end
end
