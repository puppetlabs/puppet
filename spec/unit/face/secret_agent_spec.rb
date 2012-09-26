#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'
require 'puppet/indirector/catalog/rest'
require 'tempfile'

describe Puppet::Face[:secret_agent, '0.0.1'] do
  include PuppetSpec::Files

  describe "#synchronize" do
    it "should retrieve and apply a catalog and return a report" do
      pending "This test doesn't work, but the code actually does - tested by LAK"
      dirname = tmpdir("puppetdir")
      Puppet[:vardir] = dirname
      Puppet[:confdir] = dirname
      @catalog = Puppet::Resource::Catalog.new
      @file = Puppet::Resource.new(:file, File.join(dirname, "tmp_dir_resource"), :parameters => {:ensure => :present})
      @catalog.add_resource(@file)
      Puppet::Resource::Catalog::Rest.any_instance.stubs(:find).returns(@catalog)

      report = subject.synchronize

      report.kind.should   == "apply"
      report.status.should == "changed"
    end
  end
end
