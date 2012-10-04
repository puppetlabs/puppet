#! /usr/bin/env ruby -S rspec
require 'spec_helper'
require 'puppet/settings/config_file'

describe Puppet::Settings::ConfigFile do
  NOTHING = {}

  def section_containing(data)
    meta = data[:meta] || {}
    values = data.reject { |key, _| key == :meta }
    values.merge({ :_meta => Hash[values.keys.collect { |key| [key, meta[key] || {}] }] })
  end

  def the_parse_of(*lines)
    config.parse_file(filename, lines.join("\n"))
  end

  let(:identity_transformer) { Proc.new { |value| value } }
  let(:config) { Puppet::Settings::ConfigFile.new(identity_transformer) }

  let(:filename) { "a/fake/filename.conf" }

  it "interprets an empty file to contain a main section with no entries" do
    the_parse_of("").should == { :main => section_containing(NOTHING) }
  end

  it "interprets an empty main section the same as an empty file" do
    the_parse_of("").should == config.parse_file(filename, "[main]")
  end

  it "places an entry in no section in main" do
    the_parse_of("var = value").should == { :main => section_containing(:var => "value") }
  end

  it "places an entry after a section header in that section" do
    the_parse_of("[section]", "var = value").should == { :main => section_containing(NOTHING),
                                                       :section => section_containing(:var => "value") }
  end

  it "does not include trailing whitespace in the value" do
    the_parse_of("var = value\t ").should == { :main => section_containing(:var => "value") }
  end

  it "does not include leading whitespace in the name" do
    the_parse_of("  \t var=value").should == { :main => section_containing(:var => "value") }
  end

  it "skips lines that are commented out" do
    the_parse_of("#var = value").should == { :main => section_containing(NOTHING) }
  end

  it "skips lines that are entirely whitespace" do
    the_parse_of("   \t ").should == { :main => section_containing(NOTHING) }
  end

  it "errors when a line is not a known form" do
    expect { the_parse_of("unknown") }.to raise_error Puppet::Settings::ParseError, /Could not match line/
  end

  it "stores file meta information in the _meta section" do
    the_parse_of("var = value { owner = me, group = you, mode = 0666 }").should ==
      { :main => section_containing(:var => "value", :meta => { :var => { :owner => "me",
                                                                          :group => "you",
                                                                          :mode => "0666" } }) }
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

  it "errors when an application_defaults section is created" do
    expect { the_parse_of("[application_defaults]") }.
      to raise_error Puppet::Error,
        "Illegal section 'application_defaults' in config file #{filename} at line [application_defaults]"
  end

  it "transforms values with the given function" do
    config = Puppet::Settings::ConfigFile.new(Proc.new { |value| value + " changed" })

    config.parse_file(filename, "var = value").should == { :main => section_containing(:var => "value changed") }
  end

  it "does not try to transform an entry named 'mode'" do
    config = Puppet::Settings::ConfigFile.new(Proc.new { raise "Should not transform" })

    config.parse_file(filename, "mode = value").should == { :main => section_containing(:mode => "value") }
  end
end

