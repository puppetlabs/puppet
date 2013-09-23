#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/parser/files'

describe "the epptemplate function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    Puppet[:parser] = "future"
  end

  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  it "concatenates template results for multiple templates" do
    File.stubs(:read).with("template1").returns("monkey")
    File.stubs(:read).with("template2").returns("wants banana")

    FileTest.stubs(:exist?).with('/dev/null/manifests/site.pp').returns(true)
    File.stubs(:exists?).with('/dev/null/manifests/site.pp').returns(true)
    File.stubs(:read).with("/dev/null/manifests/site.pp").returns("")
    FileTest.stubs(:exist?).with("template1").returns(true)
    FileTest.stubs(:exist?).with("template2").returns(true)
    FileTest.stubs(:exists?).with("template1").returns(true)
    FileTest.stubs(:exists?).with("template2").returns(true)
    File.stubs(:exists?).with("template1").returns(true)
    File.stubs(:exists?).with("template2").returns(true)

    Puppet::Parser::Files.stubs(:find_template).with("template1", "production").returns("template1")
    Puppet::Parser::Files.stubs(:find_template).with("template2", "production").returns("template2")

    scope.function_epptemplate(['template1', 'template2']).should == "monkeywants banana"
  end

  context "when called with one template" do
    before :each do |t|
      FileTest.stubs(:exist?).with("template").returns(true)
      FileTest.stubs(:exists?).with("template").returns(true)
      File.stubs(:exists?).with("template").returns(true)
      FileTest.stubs(:exist?).with('/dev/null/manifests/site.pp').returns(true)
      File.stubs(:exists?).with('/dev/null/manifests/site.pp').returns(true)
      File.stubs(:read).with("/dev/null/manifests/site.pp").returns("")

      Puppet::Parser::Files.stubs(:find_template).with("template", "production").returns("template")
    end

    it "should raise an error if the template raises an error" do
      expect { eval_epptemplate("<% missing end tag") }.to raise_error(/Unbalanced/)
    end

    it "makes use of a local scope so assignments do not leak"  do
      eval_epptemplate("this is a template<% $x = 10 %> where x = <%= $x %>").should == "this is a template where x = 10"
      scope['x'].should == nil
    end

    it "passes arguments to the template even if template does not declare any" do
      eval_epptemplate("this is a template where x = <%= $x %>", {'x' => 20}).should == "this is a template where x = 20"
    end

    it "passes arguments to a template that declares parameters" do
      eval_epptemplate("<%($x)%>this is a template where x = <%= $x %>", {'x' => 30}).should == "this is a template where x = 30"
    end

    it "sets default arguments if they are missing" do
      eval_epptemplate("<%($x='cigar')%>this is a template where x = <%= $x %>").should == "this is a template where x = cigar"
    end

    it "raises an error if a required parameter is not given" do
      expect { 
        eval_epptemplate("<%($x)%>this is a template where x = <%= $x %>").should == "this is a template where x = ??"
      }.to raise_error(/Missing required argument: x/)
    end
  end

  def eval_epptemplate(content, *args)
    File.stubs(:read).with("template").returns(content)
    scope.function_epptemplate(['template']+args)
  end

end
