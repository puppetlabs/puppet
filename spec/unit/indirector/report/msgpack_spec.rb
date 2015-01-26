#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/transaction/report'
require 'puppet/indirector/report/msgpack'

describe Puppet::Transaction::Report::Msgpack, :if => Puppet.features.msgpack? do
  it "should be a subclass of the Msgpack terminus" do
    expect(Puppet::Transaction::Report::Msgpack.superclass).to equal(Puppet::Indirector::Msgpack)
  end

  it "should have documentation" do
    expect(Puppet::Transaction::Report::Msgpack.doc).not_to be_nil
  end

  it "should be registered with the report indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:report)
    expect(Puppet::Transaction::Report::Msgpack.indirection).to equal(indirection)
  end

  it "should have its name set to :msgpack" do
    expect(Puppet::Transaction::Report::Msgpack.name).to eq(:msgpack)
  end

  it "should unconditionally save/load from the --lastrunreport setting" do
    expect(subject.path(:me)).to eq(Puppet[:lastrunreport])
  end
end
