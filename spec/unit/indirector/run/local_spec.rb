#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/run/local'

describe Puppet::Run::Local do
  it "should be a subclass of Puppet::Indirector::Code" do
    Puppet::Run::Local.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should call runner.run on save and return the runner" do
    Puppet::Status.indirection.stubs(:find).returns Puppet::Status.new

    runner  = Puppet::Run.new
    runner.stubs(:run).returns(runner)

    request = Puppet::Indirector::Request.new(:indirection, :save, "anything", nil)
    request.instance = runner = Puppet::Run.new
    Puppet::Run::Local.new.save(request).should == runner
  end
end
