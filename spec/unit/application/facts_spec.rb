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
    }.to have_printed /err: puppet facts find takes 1 argument, but you gave 0/
    @logs.first.to_s.should =~ /puppet facts find takes 1 argument, but you gave 0/
  end

  it "should return facts if a key is given to find" do
    Puppet::Node::Facts.indirection.reset_terminus_class
    subject.command_line.stubs(:args).returns %w{find whatever --render-as yaml}

    expect {
      expect { subject.run }.to exit_with 0
    }.should have_printed(/object:Puppet::Node::Facts/)

    @logs.should be_empty
  end
end
