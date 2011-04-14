#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/application/apply'

describe "apply" do
  include PuppetSpec::Files

  describe "when applying provided catalogs", :if => Puppet.features.pson? do
    it "should be able to apply catalogs provided in a file in pson" do
      file_to_create = tmpfile("pson_catalog")
      catalog = Puppet::Resource::Catalog.new
      resource = Puppet::Resource.new(:file, file_to_create, :parameters => {:content => "my stuff"})
      catalog.add_resource resource

      manifest = tmpfile("manifest")

      File.open(manifest, "w") { |f| f.print catalog.to_pson }

      puppet = Puppet::Application[:apply]
      puppet.options[:catalog] = manifest

      puppet.apply

      File.should be_exist(file_to_create)
      File.read(file_to_create).should == "my stuff"
    end
  end
end
