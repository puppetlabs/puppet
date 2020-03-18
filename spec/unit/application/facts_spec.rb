require 'spec_helper'
require 'puppet/application/facts'

describe Puppet::Application::Facts do
  let(:app) { Puppet::Application[:facts] }
  let(:values) { {"filesystems" => "apfs,autofs,devfs"} }

  before :each do
    Puppet::Node::Facts.indirection.terminus_class = :memory
  end

  it "return facts for a given node" do
    facts = Puppet::Node::Facts.new('whatever', values)
    Puppet::Node::Facts.indirection.save(facts)

    app.command_line.args = %w{find whatever --render-as yaml}

    # due to PUP-10105 we emit the class tag when we shouldn't
    expected = Regexp.new(<<~END)
      --- !ruby/object:Puppet::Node::Facts
      name: whatever
      values:
        filesystems: apfs,autofs,devfs
    END

    expect {
      app.run
    }.to exit_with(0)
     .and output(expected).to_stdout
  end

  it "return facts for the current node when the name is omitted" do
    facts = Puppet::Node::Facts.new(Puppet[:certname], values)
    Puppet::Node::Facts.indirection.save(facts)

    app.command_line.args = %w{find --render-as yaml}

    # due to PUP-10105 we emit the class tag when we shouldn't
    expected = Regexp.new(<<~END)
      --- !ruby/object:Puppet::Node::Facts
      name: #{Puppet[:certname]}
      values:
        filesystems: apfs,autofs,devfs
    END

    expect {
      app.run
    }.to exit_with(0)
     .and output(expected).to_stdout
  end
end
