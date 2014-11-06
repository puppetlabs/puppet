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
      config.set("the_section", "name", "value")
    end

    expect(config_fh.string).to eq "[the_section]\nname = value\n"
  end

  it "does not add a [main] section to a file when it isn't needed" do
    config_fh = a_config_file_containing(<<-CONF)
    [section]
    name = different value
    CONF


    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("main", "name", "value")
    end

    expect(config_fh.string).to eq(<<-CONF)
name = value
    [section]
    name = different value
    CONF
  end

  it "preserves comments when writing a new name and value" do
    config_fh = a_config_file_containing("# this is a comment")

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("the_section", "name", "value")
    end

    expect(config_fh.string).to eq "# this is a comment\n[the_section]\nname = value\n"
  end

  it "updates existing names and values in place" do
    config_fh = a_config_file_containing(<<-CONFIG)
    # this is the preceding comment
     [section]
    name = original value
    # this is the trailing comment
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("section", "name", "changed value")
    end

    expect(config_fh.string).to eq <<-CONFIG
    # this is the preceding comment
     [section]
    name = changed value
    # this is the trailing comment
    CONFIG
  end

  it "updates only the value in the selected section" do
    config_fh = a_config_file_containing(<<-CONFIG)
    [other_section]
    name = does not change
    [section]
    name = original value
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("section", "name", "changed value")
    end

    expect(config_fh.string).to eq <<-CONFIG
    [other_section]
    name = does not change
    [section]
    name = changed value
    CONFIG
  end

  it "considers settings outside a section to be in section 'main'" do
    config_fh = a_config_file_containing(<<-CONFIG)
    name = original value
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("main", "name", "changed value")
    end

    expect(config_fh.string).to eq <<-CONFIG
    name = changed value
    CONFIG
  end

  it "adds new settings to an existing section" do
    config_fh = a_config_file_containing(<<-CONFIG)
    [section]
    original = value

    # comment about 'other' section
    [other]
    dont = change
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("section", "updated", "new")
    end

    expect(config_fh.string).to eq <<-CONFIG
    [section]
    original = value
updated = new

    # comment about 'other' section
    [other]
    dont = change
    CONFIG
  end

  it "adds a new setting into an existing, yet empty section" do
    config_fh = a_config_file_containing(<<-CONFIG)
    [section]
    [other]
    dont = change
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("section", "updated", "new")
    end

    expect(config_fh.string).to eq <<-CONFIG
    [section]
updated = new
    [other]
    dont = change
    CONFIG
  end

  it "finds settings when the section is split up" do
    config_fh = a_config_file_containing(<<-CONFIG)
    [section]
    name = original value
    [different]
    name = other value
    [section]
    other_name = different original value
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("section", "name", "changed value")
      config.set("section", "other_name", "other changed value")
    end

    expect(config_fh.string).to eq <<-CONFIG
    [section]
    name = changed value
    [different]
    name = other value
    [section]
    other_name = other changed value
    CONFIG
  end

  def a_config_file_containing(text)
    StringIO.new(text)
  end
end
