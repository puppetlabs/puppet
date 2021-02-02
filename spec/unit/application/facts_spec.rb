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

    it 'displays a single fact value' do
      app.command_line.args << 'filesystems' << '--value-only'
      expect {
        app.run
      }.to exit_with(0)
       .and output("apfs,autofs,devfs\n").to_stdout
    end

    it "warns and ignores value-only when multiple fact names are specified" do
      app.command_line.args << 'filesystems' << 'macaddress' << '--value-only'
      expect {
        app.run
      }.to exit_with(0)
       .and output(expected).to_stdout
       .and output(/it can only be used when querying for a single fact/).to_stderr
    end

    {
      "type_hash" => [{'a' => 2}, "{\n  \"a\": 2\n}"],
      "type_array" => [[], "[\n\n]"],
      "type_string" => ["str", "str"],
      "type_int" => [1, "1"],
      "type_float" => [1.0, "1.0"],
      "type_true" => [true, "true"],
      "type_false" => [false, "false"],
      "type_nil" => [nil, ""],
      "type_sym" => [:sym, "sym"]
    }.each_pair do |name, values|
      it "renders '#{name}' as '#{values.last}'" do
        fact_value = values.first
        fact_output = values.last

        allow(Facter).to receive(:resolve).and_return({name => fact_value})

        app.command_line.args << name << '--value-only'
        expect {
          app.run
        }.to exit_with(0)
         .and output("#{fact_output}\n").to_stdout
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
