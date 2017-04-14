#! /usr/bin/env ruby
require 'spec_helper'

require 'matchers/json'

describe Puppet::Status do
  include JSONMatchers

  it "should implement find" do
    expect(Puppet::Status.indirection.find( :default )).to be_is_a(Puppet::Status)
    expect(Puppet::Status.indirection.find( :default ).status["is_alive"]).to eq(true)
  end

  it "should default to is_alive is true" do
    expect(Puppet::Status.new.status["is_alive"]).to eq(true)
  end

  it "should return a json hash" do
    expect(Puppet::Status.new.status.to_json).to eq('{"is_alive":true}')
  end

  it "should render to a json hash" do
    expect(JSON::pretty_generate(Puppet::Status.new)).to match(/"is_alive":\s*true/)
  end

  it "should accept a hash from json" do
    status = Puppet::Status.new( { "is_alive" => false } )
    expect(status.status).to eq({ "is_alive" => false })
  end

  it "should have a name" do
    Puppet::Status.new.name
  end

  it "should allow a name to be set" do
    Puppet::Status.new.name = "status"
  end

  it "serializes to JSON that conforms to the status schema" do
    status = Puppet::Status.new
    status.version = Puppet.version

    expect(status.render('json')).to validate_against('api/schemas/status.json')
  end
end
