#! /usr/bin/env ruby
require 'spec_helper'

require 'strscan'
require 'puppet/pops'

Puppet::Pops::Parser::EppScanner

describe 'Puppet::Pops::Parser::EppScanner' do
  it "should scan text to start of code token <%" do
    scanner = StringScanner.new("abc 123 <% code %>")
    ts = Puppet::Pops::Parser::EppScanner.new(scanner)
    ts.scan.should == "abc 123 "
    # the <% token should be removed
    scanner.peek(8).should == " code %>"
    ts.mode.should == :epp
  end

  it "should scan text to start of code token <% and include literal <%% %%>" do
    scanner = StringScanner.new("abc 123 <%% literal %%> <% code %>")
    ts = Puppet::Pops::Parser::EppScanner.new(scanner)
    ts.scan.should == "abc 123 <% literal %> "
    # the <% token should be removed
    scanner.peek(8).should == " code %>"
    ts.mode.should == :epp
  end

  it "should trim leading whitespace when token is <%-" do
    scanner = StringScanner.new("abc 123 \t <%- code %>")
    ts = Puppet::Pops::Parser::EppScanner.new(scanner)
    ts.scan.should == "abc 123"
    # the <%- token should be removed
    scanner.peek(8).should == " code %>"
    ts.mode.should == :epp
  end

  it "should limit trimming leading whitespace to the same line when token is <%-" do
    scanner = StringScanner.new("abc 123  \n  \t <%- code %>")
    ts = Puppet::Pops::Parser::EppScanner.new(scanner)
    ts.scan.should == "abc 123  "
    # the <%- token should be removed
    scanner.peek(8).should == " code %>"
    ts.mode.should == :epp
  end

  it "should scan text to end of input if start of code token is missing" do
    scanner = StringScanner.new("abc 123 def 456")
    ts = Puppet::Pops::Parser::EppScanner.new(scanner)
    ts.scan.should == "abc 123 def 456"
    ts.mode.should == :text
  end

  it "should report error if ending with code token <%" do
    scanner = StringScanner.new("abc 123 def 456<%")
    ts = Puppet::Pops::Parser::EppScanner.new(scanner)
    ts.scan.should == "abc 123 def 456<%"
    ts.mode.should == :error
    ts.message.should =~ /Unbalanced/
  end

  context "when dealing with comments" do
    it "should not include the comment text" do
      scanner = StringScanner.new("abc 123 <%# comment %>def 456")
      ts = Puppet::Pops::Parser::EppScanner.new(scanner)
      ts.scan.should == "abc 123 def 456"
      ts.mode.should == :text
    end

    it "should count number of processed lines" do
      scanner = StringScanner.new("abc 123 <%# comment \nfoo\n%>def 456")
      ts = Puppet::Pops::Parser::EppScanner.new(scanner)
      ts.scan.should == "abc 123 def 456"
      ts.mode.should == :text
    end

    it "should include literal <%% %%> in comment" do
      scanner = StringScanner.new("abc 123 <%# comment <%% \nfoo\n %%>\n%>def 456")
      ts = Puppet::Pops::Parser::EppScanner.new(scanner)
      ts.scan.should == "abc 123 def 456"
      ts.mode.should == :text
    end

    it "should skip leading after comment ending with -%" do
      scanner = StringScanner.new("abc 123<%# comment -%> def 456")
      ts = Puppet::Pops::Parser::EppScanner.new(scanner)
      ts.scan.should == "abc 123def 456"
      ts.mode.should == :text
    end

  end
end