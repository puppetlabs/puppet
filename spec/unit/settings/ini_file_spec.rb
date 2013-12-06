require 'spec_helper'
require 'stringio'

require 'puppet/settings/ini_file'

describe Puppet::Settings::IniFile do
  it "preserves the file when no changes are made" do
    original_config = <<-CONFIG
    # comment
    [section]
    name = value
    CONFIG
    config_fh = a_config_file_containing(original_config)

    Puppet::Settings::IniFile.update(config_fh) do; end

    expect(config_fh.string).to eq original_config
  end

  it "adds a set name and value to an empty file" do
    config_fh = a_config_file_containing("")

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("name", "value")
    end

    expect(config_fh.string).to eq "name=value\n"
  end

  it "preserves comments when writing a new name and value" do
    config_fh = a_config_file_containing("# this is a comment")

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("name", "value")
    end

    expect(config_fh.string).to eq "# this is a comment\nname=value\n"
  end

  it "updates existing names and values in place" do
    config_fh = a_config_file_containing(<<-CONFIG)
    # this is the preceeding comment
     [section]
    name = original value
    # this is the trailing comment
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("name", "changed value")
    end

    expect(config_fh.string).to eq <<-CONFIG
    # this is the preceeding comment
     [section]
    name = changed value
    # this is the trailing comment
    CONFIG
  end

  def a_config_file_containing(text)
    StringIO.new(text)
  end
end
