require 'spec_helper'
require 'puppet/application/facts'

describe Puppet::Application::Facts do
  let(:app) { Puppet::Application[:facts] }
  let(:values) { {"filesystems" => "apfs,autofs,devfs", "macaddress" => "64:52:11:22:03:25"} }

  before :each do
    Puppet::Node::Facts.indirection.terminus_class = :memory
  end

  it "returns facts for a given node" do
    facts = Puppet::Node::Facts.new('whatever', values)
    Puppet::Node::Facts.indirection.save(facts)

    app.command_line.args = %w{find whatever --render-as yaml}

    # due to PUP-10105 we emit the class tag when we shouldn't
    expected = Regexp.new(<<~END)
      --- !ruby/object:Puppet::Node::Facts
      name: whatever
      values:
        filesystems: apfs,autofs,devfs
        macaddress: "64:52:11:22:03:25"
    END

    expect {
      app.run
    }.to exit_with(0)
     .and output(expected).to_stdout
  end

  it "returns facts for the current node when the name is omitted" do
    facts = Puppet::Node::Facts.new(Puppet[:certname], values)
    Puppet::Node::Facts.indirection.save(facts)

    app.command_line.args = %w{find --render-as yaml}

    # due to PUP-10105 we emit the class tag when we shouldn't
    expected = Regexp.new(<<~END)
      --- !ruby/object:Puppet::Node::Facts
      name: #{Puppet[:certname]}
      values:
        filesystems: apfs,autofs,devfs
        macaddress: "64:52:11:22:03:25"
    END

    expect {
      app.run
    }.to exit_with(0)
     .and output(expected).to_stdout
  end

  context 'when show action is called' do
    let(:expected) { <<~END }
      {
        "filesystems": "apfs,autofs,devfs",
        "macaddress": "64:52:11:22:03:25"
      }
    END

    before :each do
      Puppet::Node::Facts.indirection.terminus_class = :facter
      allow(Facter).to receive(:resolve).and_return(values)
      app.command_line.args = %w{show}
    end

    it 'correctly displays facts with default formatting' do
      expect {
        app.run
      }.to exit_with(0)
       .and output(expected).to_stdout
    end
    end
  end

  context 'when default action is called' do
    let(:expected) { <<~END }
      ---
      filesystems: apfs,autofs,devfs
      macaddress: 64:52:11:22:03:25
    END

    before :each do
      Puppet::Node::Facts.indirection.terminus_class = :facter
      allow(Facter).to receive(:resolve).and_return(values)
      app.command_line.args = %w{--render-as yaml}
    end

    it 'calls show action' do
      expect {
        app.run
      }.to exit_with(0)
       .and output(expected).to_stdout
      expect(app.action.name).to eq(:show)
    end
  end
end
