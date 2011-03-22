#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/configurer'
require 'puppet/indirector/catalog/rest'
require 'tempfile'

describe Puppet::Interface.interface(:configurer) do
  describe "#synchronize" do
    it "should retrieve and apply a catalog and return a report" do
      dirname = Dir.mktmpdir("puppetdir")
      Puppet[:vardir] = dirname
      Puppet[:confdir] = dirname
      @catalog = Puppet::Resource::Catalog.new
      @file = Puppet::Resource.new(:file, File.join(dirname, "tmp_dir_resource"), :parameters => {:ensure => :present})
      @catalog.add_resource(@file)
      Puppet::Resource::Catalog::Rest.any_instance.stubs(:find).returns(@catalog)

      report = Puppet::Interface.interface(:configurer).synchronize("foo")

      report.kind.should   == "apply"
      report.status.should == "changed"
    end
  end
end
