#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:config, '0.0.1'] do
  it "prints a single setting without the name" do
    Puppet[:trace] = true

    subject.expects(:puts).with(true)

    subject.print("trace").should be_nil
  end

  it "prints multiple settings with the names" do
    Puppet[:trace] = true
    Puppet[:syslogfacility] = "file"

    subject.expects(:puts).with("trace = true")
    subject.expects(:puts).with("syslogfacility = file")

    subject.print("trace", "syslogfacility")
  end

  it "prints the setting from the selected section" do
    Puppet.settings.parse_config(<<-CONF)
    [other]
    syslogfacility = file
    CONF

    subject.expects(:puts).with("file")

    subject.print("syslogfacility", :section => "other")
  end

  it "should default to all when no arguments are given" do
    subject.expects(:puts).times(Puppet.settings.to_a.length)

    subject.print
  end

  it "prints out all of the settings when asked for 'all'" do
    subject.expects(:puts).times(Puppet.settings.to_a.length)

    subject.print('all')
  end
end
