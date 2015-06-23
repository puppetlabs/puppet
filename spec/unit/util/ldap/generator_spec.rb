#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/ldap/generator'

describe Puppet::Util::Ldap::Generator do
  before do
    @generator = Puppet::Util::Ldap::Generator.new(:uno)
  end

  it "should require a parameter name at initialization" do
    expect { Puppet::Util::Ldap::Generator.new }.to raise_error(ArgumentError, /wrong number of arguments/)
  end

  it "should always return its name as a string" do
    g = Puppet::Util::Ldap::Generator.new(:myname)
    expect(g.name).to eq("myname")
  end

  it "should provide a method for declaring the source parameter" do
    @generator.from(:dos)
  end

  it "should always return a set source as a string" do
    @generator.from(:dos)
    expect(@generator.source).to eq("dos")
  end

  it "should return the source as nil if there is no source" do
    expect(@generator.source).to be_nil
  end

  it "should return itself when declaring the source" do
    expect(@generator.from(:dos)).to equal(@generator)
  end

  it "should run the provided block when asked to generate the value" do
    @generator.with { "yayness" }
    expect(@generator.generate).to eq("yayness")
  end

  it "should pass in any provided value to the block" do
    @generator.with { |value| value.upcase }
    expect(@generator.generate("myval")).to eq("MYVAL")
  end

  it "should return itself when declaring the code used for generating" do
    expect(@generator.with { |value| value.upcase }).to equal(@generator)
  end
end
