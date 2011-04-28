#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/application/facts'

describe Puppet::Application::Facts do
  before :each do
    subject.command_line.stubs(:subcommand_name).returns 'facts'
  end

  it "should fail if no key is given to find" do
    subject.command_line.stubs(:args).returns %w{find}
    expect {
      expect { subject.run }.to exit_with 1
    }.to have_printed /1 argument expected but 0 given/
    @logs.first.to_s.should =~ /1 argument expected but 0 given/
  end

  it "should return facts if a key is given to find" do
    subject.command_line.stubs(:args).returns %w{find whatever --render-as yaml}

    expect {
      expect { subject.run }.to exit_with 0
    }.should have_printed(/object:Puppet::Node::Facts/)

    @logs.should be_empty
  end
end
