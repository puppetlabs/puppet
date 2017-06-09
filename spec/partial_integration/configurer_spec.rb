#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/configurer'

describe Puppet::Configurer do
  include PuppetSpec::Files

  describe "when running" do
    before(:each) do
      @catalog = Puppet::Resource::Catalog.new("testing", Puppet.lookup(:environments).get(Puppet[:environment]))
      @catalog.add_resource(Puppet::Type.type(:notify).new(:title => "testing"))

      # Make sure we don't try to persist the local state after the transaction ran,
      # because it will fail during test (the state file is in a not-existing directory)
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
      Puppet::Transaction::Report.indirection.stubs(:save)

      Puppet[:lastrunfile] = tmpfile("lastrunfile")
      Puppet.settings.setting(:lastrunfile).mode = 0666
      Puppet[:report] = true

      # We only record integer seconds in the timestamp, and truncate
      # backwards, so don't use a more accurate timestamp in the test.
      # --daniel 2011-03-07
      t1 = Time.now.tv_sec
      @configurer.run :catalog => @catalog, :report => report
      t2 = Time.now.tv_sec

      # sticky bit only applies to directories in windows
      file_mode = Puppet.features.microsoft_windows? ? '666' : '100666'

      expect(Puppet::FileSystem.stat(Puppet[:lastrunfile]).mode.to_s(8)).to eq(file_mode)

      summary = nil
      File.open(Puppet[:lastrunfile], "r") do |fd|
        summary = YAML.load(fd.read)
      end

      expect(summary).to be_a(Hash)
      %w{time changes events resources}.each do |key|
        expect(summary).to be_key(key)
      end
      expect(summary["time"]).to be_key("notify")
      expect(summary["time"]["last_run"]).to be_between(t1, t2)
    end
  end
end
