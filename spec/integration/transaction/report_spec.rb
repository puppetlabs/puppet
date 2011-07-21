#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Transaction::Report do
  describe "when using the indirector" do
    after do
      Puppet.settings.stubs(:use)
    end

    it "should be able to delegate to the :processor terminus" do
      Puppet::Transaction::Report.indirection.stubs(:terminus_class).returns :processor

      terminus = Puppet::Transaction::Report.indirection.terminus(:processor)

      Facter.stubs(:value).returns "host.domain.com"

      report = Puppet::Transaction::Report.new("apply")

      terminus.expects(:process).with(report)

      Puppet::Transaction::Report.indirection.save(report)
    end
  end
end
