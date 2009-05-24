#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet_spec/files'

describe Puppet::Util::Settings do
    include PuppetSpec::Files

    it "should be able to make needed directories" do
        settings = Puppet::Util::Settings.new
        settings.setdefaults :main, :maindir => [tmpfile("main"), "a"]

        settings.use(:main)

        File.should be_directory(settings[:maindir])
    end

    it "should make its directories with the corret modes" do
        settings = Puppet::Util::Settings.new
        settings.setdefaults :main, :maindir => {:default => tmpfile("main"), :desc => "a", :mode => 0750}

        settings.use(:main)

        (File.stat(settings[:maindir]).mode & 007777).should == 0750
    end
end
