#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops/api/issues'

describe "Puppet::Pops::API::Issues" do
  include Puppet::Pops::API::Issues
  it "should have an issue called NAME_WITH_HYPHEN" do
    x = Puppet::Pops::API::Issues::NAME_WITH_HYPHEN
    x.class.should == Puppet::Pops::API::Issues::Issue
    x.issue_code.should == :NAME_WITH_HYPHEN
  end
  it "should should format a message that requires an argument" do
    x = Puppet::Pops::API::Issues::NAME_WITH_HYPHEN
    x.format(:name => 'Boo-Hoo').should == "A name may not contain a hyphen. The name 'Boo-Hoo' is not legal"
  end
  it "should should format a message that does not require an argument" do
    x = Puppet::Pops::API::Issues::NOT_TOP_LEVEL
    x.format().should == "Classes, definitions, and nodes may only appear at toplevel or inside other classes"
  end
  
 end

