#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::ResourceReference do

  ast = Puppet::Parser::AST

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  def ast_name(value)
    Puppet::Parser::AST::Name.new(:value => value)
  end

  def newref(type, title)
    title_array = Puppet::Parser::AST::ASTArray.new(:children => [title])
    ref = Puppet::Parser::AST::ResourceReference.new(:type => type, :title => title_array)
  end

  it "should correctly produce reference strings" do
    newref("File", ast_name("/tmp/yay")).evaluate(@scope).to_s.should == "File[/tmp/yay]"
  end

  it "should produce a single resource when the title evaluates to a string" do
    newref("File", ast_name("/tmp/yay")).evaluate(@scope).should == Puppet::Resource.new("file", "/tmp/yay")
  end

  it "should return an array of resources if given an array of titles" do
    titles = Puppet::Parser::AST::ASTArray.new(:children => [ast_name("title1"), ast_name("title2")])
    ref = ast::ResourceReference.new( :title => titles, :type => "File" )
    ref.evaluate(@scope).should == [
      Puppet::Resource.new("file", "title1"),
      Puppet::Resource.new("file", "title2")
    ]
  end

  it "should return an array of resources if given a variable containing an array of titles" do
    @scope["my_files"] = ["foo", "bar"]
    titles = Puppet::Parser::AST::Variable.new(:value => "my_files")
    ref = newref('File', titles)
    ref.evaluate(@scope).should == [
      Puppet::Resource.new("file", "foo"),
      Puppet::Resource.new("file", "bar")
    ]
  end

  it "should return a correct representation when converting to string" do
    type = stub 'type', :is_a? => true, :to_s => "file"
    title = stub 'title', :is_a? => true, :to_s => "[/tmp/a, /tmp/b]"

    ast::ResourceReference.new( :type => type, :title => title ).to_s.should == "File[/tmp/a, /tmp/b]"
  end
end
