#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/application/facts'

describe Puppet::Application::Facts do
  before :each do
    subject.command_line.stubs(:subcommand_name).returns 'facts'
  end

  it "should return facts if a key is given to find" do
    Puppet::Node::Facts.indirection.reset_terminus_class
    Puppet::Node::Facts.indirection.expects(:find).returns(Puppet::Node::Facts.new('whatever', {}))
    subject.command_line.stubs(:args).returns %w{find whatever --render-as yaml}

    expect {
      expect {
        subject.run
      }.to exit_with(0)
    }.to have_printed(/object:Puppet::Node::Facts/)

    expect(@logs).to be_empty
  end
end
