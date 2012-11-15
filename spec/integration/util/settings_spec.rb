#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'

describe Puppet::Settings do
  include PuppetSpec::Files

  def minimal_default_settings
    { :noop => {:default => false, :desc => "noop"} }
  end

  it "should be able to make needed directories" do
    settings = Puppet::Settings.new
    settings.define_settings :main, minimal_default_settings.update(
        :maindir => {
            :default => tmpfile("main"),
            :type => :directory,
            :desc => "a",
        }
    )
    settings.use(:main)

    File.should be_directory(settings[:maindir])
  end

  it "should make its directories with the correct modes" do
    settings = Puppet::Settings.new
    settings.define_settings :main,  minimal_default_settings.update(
        :maindir => {
            :default => tmpfile("main"),
            :type => :directory,
            :desc => "a",
            :mode => 0750
        }
    )

    settings.use(:main)

    (File.stat(settings[:maindir]).mode & 007777).should == (Puppet.features.microsoft_windows? ? 0755 : 0750)
  end
end
