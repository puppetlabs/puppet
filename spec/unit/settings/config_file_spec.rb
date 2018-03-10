#! /usr/bin/env ruby -S rspec
require 'spec_helper'
require 'puppet/settings/config_file'

describe Puppet::Settings::ConfigFile do
  NOTHING = {}

  def the_parse_of(*lines)
    config.parse_file(filename, lines.join("\n"))
  end

  let(:identity_transformer) { Proc.new { |value| value } }
  let(:config) { Puppet::Settings::ConfigFile.new(identity_transformer) }

  let(:filename) { "a/fake/filename.conf" }

  Conf = Puppet::Settings::ConfigFile::Conf
  Section = Puppet::Settings::ConfigFile::Section
  Meta = Puppet::Settings::ConfigFile::Meta
  NO_META = Puppet::Settings::ConfigFile::NO_META

  it "interprets an empty file to contain a main section with no entries" do
    result = the_parse_of("")

    expect(result).to eq(Conf.new.with_section(Section.new(:main)))
  end

  it "interprets an empty main section the same as an empty file" do
    expect(the_parse_of("")).to eq(config.parse_file(filename, "[main]"))
  end

  it "places an entry in no section in main" do
    result = the_parse_of("var = value")

    expect(result).to eq(Conf.new.with_section(Section.new(:main).with_setting(:var, "value", NO_META)))
  end

  it "places an entry after a section header in that section" do
    result = the_parse_of("[agent]", "var = value")

    expect(result).to eq(Conf.new.
                         with_section(Section.new(:main)).
                         with_section(Section.new(:agent).
                                      with_setting(:var, "value", NO_META)))
  end

  it "does not include trailing whitespace in the value" do
    result = the_parse_of("var = value\t ")

    expect(result).to eq(Conf.new.
                         with_section(Section.new(:main).
                                      with_setting(:var, "value", NO_META)))
  end

  it "does not include leading whitespace in the name" do
    result = the_parse_of("  \t var=value")

    expect(result).to eq(Conf.new.
                         with_section(Section.new(:main).
                                      with_setting(:var, "value", NO_META)))
  end

  it "skips lines that are commented out" do
    result = the_parse_of("#var = value")

    expect(result).to eq(Conf.new.with_section(Section.new(:main)))
  end

  it "skips lines that are entirely whitespace" do
    result = the_parse_of("   \t ")

    expect(result).to eq(Conf.new.with_section(Section.new(:main)))
  end

  it "errors when a line is not a known form" do
    expect { the_parse_of("unknown") }.to raise_error Puppet::Settings::ParseError, /Could not match line/
  end

  it "errors providing correct line number when line is not a known form" do
    multi_line_config = <<-EOF
[main]
foo=bar
badline
    EOF
    expect { the_parse_of(multi_line_config) }.to(
        raise_error(Puppet::Settings::ParseError, /Could not match line/) do |exception|
          expect(exception.line).to eq(3)
        end
      )
  end

  it "stores file meta information in the _meta section" do
    result = the_parse_of("var = value { owner = me, group = you, mode = 0666 }")

    expect(result).to eq(Conf.new.with_section(Section.new(:main).
                                               with_setting(:var, "value",
                                                            Meta.new("me", "you", "0666"))))
  end

  it "errors when there is unknown meta information" do
    expect { the_parse_of("var = value { unknown = no }") }.
      to raise_error ArgumentError, /Invalid file option 'unknown'/
  end

  it "errors when the mode is not numeric" do
    expect { the_parse_of("var = value { mode = no }") }.
      to raise_error ArgumentError, "File modes must be numbers"
  end

  it "errors when the options are not key-value pairs" do
    expect { the_parse_of("var = value { mode }") }.
      to raise_error ArgumentError, "Could not parse 'value { mode }'"
  end

  it "may specify legal sections" do
    text = <<-EOF
      [legal]
      a = 'b'
      [illegal]
      one = 'e'
      two = 'f'
    EOF

    expect { config.parse_file(filename, text, [:legal]) }.
      to raise_error Puppet::Error,
        /Illegal section 'legal' in config file at \(file: #{filename}, line: 1\)/
  end

  it "transforms values with the given function" do
    config = Puppet::Settings::ConfigFile.new(Proc.new { |value| value + " changed" })

    result = config.parse_file(filename, "var = value")

    expect(result).to eq(Conf.new.
                            with_section(Section.new(:main).
                                         with_setting(:var, "value changed", NO_META)))
  end

  it "does not try to transform an entry named 'mode'" do
    config = Puppet::Settings::ConfigFile.new(Proc.new { raise "Should not transform" })

    result = config.parse_file(filename, "mode = value")

    expect(result).to eq(Conf.new.
                            with_section(Section.new(:main).
                                         with_setting(:mode, "value", NO_META)))
  end
end

