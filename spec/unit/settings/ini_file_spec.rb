require 'spec_helper'
require 'stringio'

require 'puppet/settings/ini_file'

describe Puppet::Settings::IniFile do
  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ𠜎

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

  it "adds a UTF-8 name and value to an empty file" do
    config_fh = a_config_file_containing("")

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("the_section", mixed_utf8, mixed_utf8.reverse)
    end

    expect(config_fh.string).to eq "[the_section]\n#{mixed_utf8} = #{mixed_utf8.reverse}\n"
  end

  it "adds a [main] section to a file when it's needed" do
    config_fh = a_config_file_containing(<<-CONF)
    [section]
    name = different value
    CONF


    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("main", "name", "value")
    end

    expect(config_fh.string).to eq(<<-CONF)
[main]
name = value
    [section]
    name = different value
    CONF
  end

  it "can update values within a UTF-8 section of an existing file" do
    config_fh = a_config_file_containing(<<-CONF)
    [#{mixed_utf8}]
    foo = default
    CONF

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set(mixed_utf8, 'foo', 'bar')
    end

    expect(config_fh.string).to eq(<<-CONF)
    [#{mixed_utf8}]
    foo = bar
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

  it "updates existing empty settings" do
    config_fh = a_config_file_containing(<<-CONFIG)
    # this is the preceding comment
     [section]
    name = 
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

  it "can set empty settings" do
    config_fh = a_config_file_containing(<<-CONFIG)
    # this is the preceding comment
     [section]
    name = original value
    # this is the trailing comment
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("section", "name", "")
    end

    expect(config_fh.string).to eq <<-CONFIG
    # this is the preceding comment
     [section]
    name = 
    # this is the trailing comment
    CONFIG
  end

  it "updates existing UTF-8 name / values in place" do
    config_fh = a_config_file_containing(<<-CONFIG)
    # this is the preceding comment
     [section]
    ascii = foo
    #{mixed_utf8} = bar
    # this is the trailing comment
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("section", "ascii", mixed_utf8)
      config.set("section", mixed_utf8, mixed_utf8.reverse)
    end

    expect(config_fh.string).to eq <<-CONFIG
    # this is the preceding comment
     [section]
    ascii = #{mixed_utf8}
    #{mixed_utf8} = #{mixed_utf8.reverse}
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

  it "considers settings found outside a section to be in section 'main'" do
    config_fh = a_config_file_containing(<<-CONFIG)
    name = original value
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("main", "name", "changed value")
    end

    expect(config_fh.string).to eq <<-CONFIG
[main]
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

  it "adds a new setting to the appropriate section, when it would be added behind a setting with an identical value in a preceeding section" do
    config_fh = a_config_file_containing(<<-CONFIG)
    [different]
    name = some value
    [section]
    name = some value
    CONFIG

    Puppet::Settings::IniFile.update(config_fh) do |config|
      config.set("section", "new", "new value")
    end

    expect(config_fh.string).to eq <<-CONFIG
    [different]
    name = some value
    [section]
    name = some value
new = new value
    CONFIG
  end

  context 'config with no main section' do
    it 'file does not change when there are no sections or entries' do
      config_fh = a_config_file_containing(<<-CONFIG)
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('main', 'missing')
      end

      expect(config_fh.string).to eq <<-CONFIG
      CONFIG
    end

    it 'when there is only 1 entry we can delete it' do
      config_fh = a_config_file_containing(<<-CONFIG)
      base = value
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('main', 'base')
      end

      expect(config_fh.string).to eq <<-CONFIG
      CONFIG
    end

    it 'we delete 1 entry from the default section and add the [main] section header' do
      config_fh = a_config_file_containing(<<-CONFIG)
      base = value
      other = another value
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('main', 'base')
      end

      expect(config_fh.string).to eq <<-CONFIG
[main]
      other = another value
      CONFIG
    end

    it 'we add [main] to the config file when attempting to delete a setting in another section' do
      config_fh = a_config_file_containing(<<-CONF)
      name = different value
      CONF

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('section', 'name')
      end

      expect(config_fh.string).to eq(<<-CONF)
[main]
      name = different value
      CONF
    end
  end

  context 'config with 1 section' do
    it 'file does not change when entry to delete does not exist' do
      config_fh = a_config_file_containing(<<-CONFIG)
      [main]
      base = value
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('main', 'missing')
      end

      expect(config_fh.string).to eq <<-CONFIG
      [main]
      base = value
      CONFIG
    end

    it 'deletes the 1 entry in the section' do
      config_fh = a_config_file_containing(<<-CONFIG)
      [main]
      base = DELETING
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('main', 'base')
      end

      expect(config_fh.string).to eq <<-CONFIG
      [main]
      CONFIG
    end

    it 'deletes the entry and leaves another entry' do
      config_fh = a_config_file_containing(<<-CONFIG)
      [main]
      base = DELETING
      after = value to keep
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('main', 'base')
      end

      expect(config_fh.string).to eq <<-CONFIG
      [main]
      after = value to keep
      CONFIG
    end

    it 'deletes the entry while leaving other entries' do
      config_fh = a_config_file_containing(<<-CONFIG)
      [main]
      before = value to keep before
      base = DELETING
      after = value to keep
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('main', 'base')
      end

      expect(config_fh.string).to eq <<-CONFIG
      [main]
      before = value to keep before
      after = value to keep
      CONFIG
    end

    it 'when there are two entries of the same setting name delete one of them' do
      config_fh = a_config_file_containing(<<-CONFIG)
      [main]
      base = value
      base = value
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('main', 'base')
      end

      expect(config_fh.string).to eq <<-CONFIG
      [main]
      base = value
      CONFIG
    end
  end

  context 'with 2 sections' do
    it 'file does not change when entry to delete does not exist' do
      config_fh = a_config_file_containing(<<-CONFIG)
      [main]
      base = value
      [section]
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('section', 'missing')
      end

      expect(config_fh.string).to eq <<-CONFIG
      [main]
      base = value
      [section]
      CONFIG
    end

    it 'deletes the 1 entry in the specified section' do
      config_fh = a_config_file_containing(<<-CONFIG)
      [main]
      base = value
      [section]
      base = value
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('section', 'base')
      end

      expect(config_fh.string).to eq <<-CONFIG
      [main]
      base = value
      [section]
      CONFIG
    end

    it 'deletes the entry while leaving other entries' do
      config_fh = a_config_file_containing(<<-CONFIG)
      [main]
      before = value also staying
      base = value staying
      after = value to keep
      [section]
      before value in section keeping
      base = DELETING
      after = value to keep
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('section', 'base')
      end

      expect(config_fh.string).to eq <<-CONFIG
      [main]
      before = value also staying
      base = value staying
      after = value to keep
      [section]
      before value in section keeping
      after = value to keep
      CONFIG
    end
  end

  context 'with 2 sections' do
    it 'deletes the entry while leaving other entries' do
      config_fh = a_config_file_containing(<<-CONFIG)
      [main]
      before = value also staying
      base = value staying
      after = value to keep
      [section]
      before value in section keeping
      base = DELETING
      after = value to keep
      [otherSection]
      before value in section keeping
      base = value to keep really
      after = value to keep
      CONFIG

      Puppet::Settings::IniFile.update(config_fh) do |config|
        config.delete('section', 'base')
      end

      expect(config_fh.string).to eq <<-CONFIG
      [main]
      before = value also staying
      base = value staying
      after = value to keep
      [section]
      before value in section keeping
      after = value to keep
      [otherSection]
      before value in section keeping
      base = value to keep really
      after = value to keep
      CONFIG
    end
  end


  def a_config_file_containing(text)
    # set_encoding required for Ruby 1.9.3 as ASCII is the default
    StringIO.new(text).set_encoding(Encoding::UTF_8)
  end
end
