#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Transaction::Report do
  describe "when using the indirector" do
    after do
      Puppet.settings.stubs(:use)
    end

    it "should be able to delegate to the :processor terminus" do
      Puppet::Transaction::Report.stubs(:terminus_class).returns :processor

      terminus = Puppet::Transaction::Report.terminus(:processor)

      Facter.stubs(:value).returns "host.domain.com"

      report = Puppet::Transaction::Report.new("apply")

      terminus.expects(:process).with(report)

      report.save
    end
  end
end
