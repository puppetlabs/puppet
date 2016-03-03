#! /usr/bin/env ruby
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

  describe "when dumping to YAML" do
    it "should not contain TagSet objects" do
      resource = Puppet::Resource.new(:notify, "Hello")
      ral_resource = resource.to_ral
      status = Puppet::Resource::Status.new(ral_resource)

      log = Puppet::Util::Log.new(:level => :info, :message => "foo")

      report = Puppet::Transaction::Report.new("apply")
      report.add_resource_status(status)
      report << log

      expect(YAML.dump(report)).to_not match('Puppet::Util::TagSet')
    end
  end
end
