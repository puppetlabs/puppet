#! /usr/bin/env ruby
require 'spec_helper'

describe "the inline_epptemplate function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    Puppet[:parser] = 'future'
  end

  let(:node) { Puppet::Node.new('localhost') }
  let(:compiler) { Puppet::Parser::Compiler.new(node) }
  let(:scope) { Puppet::Parser::Scope.new(compiler) }

  it "concatenates template wrapper results for multiple templates" do
    inline_epptemplate("template1", "template2").should == "template1template2"
  end

  it "should raise an error if the template raises an error" do
    expect { inline_epptemplate("<% missing end tag") }.to raise_error(/Unbalanced/)
  end

  it "makes use of a local scope so assignments do not leak" do
    inline_epptemplate("this is a template<% $x = 10 %> where x = <%= $x %>").should == "this is a template where x = 10"
    scope['x'].should == nil
  end

  it "passes arguments to the template even if template does not declare any" do
    inline_epptemplate("this is a template where x = <%= $x %>", {'x' => 20}).should == "this is a template where x = 20"
    scope['x'].should == nil
  end

  it "passes arguments to a template that declares parameters" do
    inline_epptemplate("<%($x)%>this is a template where x = <%= $x %>", {'x' => 30}).should == "this is a template where x = 30"
    scope['x'].should == nil
  end

  it "sets default arguments if they are missing" do
    inline_epptemplate("<%($x='cigar')%>this is a template where x = <%= $x %>").should == "this is a template where x = cigar"
    scope['x'].should == nil
  end

  it "raises an error if a required parameter is not given" do
    expect { 
      inline_epptemplate("<%($x)%>this is a template where x = <%= $x %>").should == "this is a template where x = ??"
    }.to raise_error(/Missing required argument: x/)
    scope['x'].should == nil
  end

  it "handles nested epp evaluation" do
    inline_epptemplate("hello <%= inline_epptemplate(\"nes<%='ted'%>\") %> world").should == "hello nested world"
  end

  it "treats intermediate results as nil" do
    inline_epptemplate("hello<% $x = %> world<%= $x %>").should == "hello world"
  end

  it "is not allowed to create a class" do
    expect {
    inline_epptemplate("<% class contraband {} %>")
    }.to raise_error(/only appear at toplevel/)
  end

  def inline_epptemplate(*templates)
    scope.function_inline_epptemplate(templates)
  end
end
