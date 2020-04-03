require 'spec_helper'
require 'puppet/application/facts'

describe Puppet::Application::Facts do
  before :each do
    allow(subject.command_line).to receive(:subcommand_name).and_return('facts')
  end

  it "should return facts if a key is given to find" do
    Puppet::Node::Facts.indirection.reset_terminus_class
    expect(Puppet::Node::Facts.indirection).to receive(:find).and_return(Puppet::Node::Facts.new('whatever', {}))
    allow(subject.command_line).to receive(:args).and_return(%w{find whatever --render-as yaml})

    expect {
      subject.run
    }.to exit_with(0)
     .and have_printed(/object:Puppet::Node::Facts/)

    expect(@logs).to be_empty
  end
end
