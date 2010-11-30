#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/configurer'

describe Puppet::Configurer do
  include PuppetSpec::Files

  describe "when downloading plugins" do
    it "should use the :pluginsignore setting, split on whitespace, for ignoring remote files" do
      resource = Puppet::Type.type(:notify).new :name => "yay"
      Puppet::Type.type(:file).expects(:new).with { |args| args[:ignore] == Puppet[:pluginsignore].split(/\s+/) }.returns resource

      configurer = Puppet::Configurer.new
      configurer.stubs(:download_plugins?).returns true
      configurer.download_plugins
    end
  end

  describe "when running" do
    before(:each) do
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource(Puppet::Type.type(:notify).new(:title => "testing"))

      # Make sure we don't try to persist the local state after the transaction ran, 
      # because it will fail during test (the state file is in an not existing directory)
      # and we need the transaction to be successful to be able to produce a summary report
      @catalog.host_config = false

      @configurer = Puppet::Configurer.new
    end

    it "should send a transaction report with valid data" do

      @configurer.stubs(:save_last_run_summary)
      Puppet::Transaction::Report.indirection.expects(:save).with do |report, x|
        report.time.class == Time and report.logs.length > 0
      end

      Puppet[:report] = true

      @configurer.run :catalog => @catalog
    end

    it "should save a correct last run summary" do
      report = Puppet::Transaction::Report.new
      report.stubs(:save)

      Puppet[:lastrunfile] = tmpfile("lastrunfile")
      Puppet[:report] = true

      @configurer.run :catalog => @catalog, :report => report

      summary = nil
      File.open(Puppet[:lastrunfile], "r") do |fd|
        summary = YAML.load(fd.read)
      end

      summary.should be_a(Hash)
      %w{time changes events resources}.each do |key|
        summary.should be_key(key)
      end
      summary["time"].should be_key("notify")
      summary["time"]["last_run"].should >= Time.now.tv_sec
    end
  end
end
