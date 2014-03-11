#! /usr/bin/env ruby
require 'spec_helper'

require 'matchers/json'

describe Puppet::Status do
  include JSONMatchers

  it "should implement find" do
    Puppet::Status.indirection.find( :default ).should be_is_a(Puppet::Status)
    Puppet::Status.indirection.find( :default ).status["is_alive"].should == true
  end

  it "should default to is_alive is true" do
    Puppet::Status.new.status["is_alive"].should == true
  end

  it "should return a pson hash" do
    Puppet::Status.new.status.to_pson.should == '{"is_alive":true}'
  end

  it "should render to a pson hash" do
    PSON::pretty_generate(Puppet::Status.new).should =~ /"is_alive":\s*true/
  end

  it "should accept a hash from pson" do
    status = Puppet::Status.new( { "is_alive" => false } )
    status.status.should == { "is_alive" => false }
  end

  it "should have a name" do
    Puppet::Status.new.name
  end

  it "should allow a name to be set" do
    Puppet::Status.new.name = "status"
  end

  it "can do a round-trip serialization via YAML" do
    status = Puppet::Status.new
    new_status = Puppet::Status.convert_from('yaml', status.render('yaml'))
    new_status.should equal_attributes_of(status)
  end

  it "serializes to PSON that conforms to the status schema" do
    status = Puppet::Status.new
    status.version = Puppet.version

    expect(status.render('pson')).to validate_against('api/schemas/status.json')
  end
end
