#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/run/local'

describe Puppet::Run::Local do
  it "should be a sublcass of Puppet::Indirector::Code" do
    Puppet::Run::Local.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should call runner.run on save and return the runner" do
    runner  = Puppet::Run.new
    runner.stubs(:run).returns(runner)

    request = Puppet::Indirector::Request.new(:indirection, :save, "anything")
    request.instance = runner = Puppet::Run.new
    Puppet::Run::Local.new.save(request).should == runner
  end
end
