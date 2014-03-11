#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/transaction/report'
require 'puppet/indirector/report/msgpack'

describe Puppet::Transaction::Report::Msgpack, :if => Puppet.features.msgpack? do
  it "should be a subclass of the Msgpack terminus" do
    Puppet::Transaction::Report::Msgpack.superclass.should equal(Puppet::Indirector::Msgpack)
  end

  it "should have documentation" do
    Puppet::Transaction::Report::Msgpack.doc.should_not be_nil
  end

  it "should be registered with the report indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:report)
    Puppet::Transaction::Report::Msgpack.indirection.should equal(indirection)
  end

  it "should have its name set to :msgpack" do
    Puppet::Transaction::Report::Msgpack.name.should == :msgpack
  end

  it "should unconditionally save/load from the --lastrunreport setting" do
    subject.path(:me).should == Puppet[:lastrunreport]
  end
end
