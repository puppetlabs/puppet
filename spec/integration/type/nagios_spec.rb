#!/usr/bin/env ruby

require 'spec_helper'
require 'puppet/file_bucket/dipper'

describe "Nagios file creation" do
  include PuppetSpec::Files

  let(:initial_mode) { 0600 }

  before :each do
    FileUtils.touch(target_file)
    Puppet::FileSystem.chmod(initial_mode, target_file)
    Puppet::FileBucket::Dipper.any_instance.stubs(:backup) # Don't backup to filebucket
  end

  let :target_file do
    tmpfile('nagios_integration_specs')
  end

  # Copied from the crontab integration spec.
  #
  # @todo This should probably live in the PuppetSpec module instead then.
  def run_in_catalog(*resources)
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false
    resources.each do |resource|
      resource.expects(:err).never
      catalog.add_resource(resource)
    end

    # the resources are not properly contained and generated resources
    # will end up with dangling edges without this stubbing:
    catalog.stubs(:container_of).returns resources[0]
    catalog.apply
  end

  context "when creating a nagios config file" do
    context "which is not managed" do
      it "should choose the file mode if requested" do
        resource = Puppet::Type.type(:nagios_host).new(
          :name   => 'spechost',
          :use    => 'spectemplate',
          :ensure => 'present',
          :target => target_file,
          :mode   => '0640'
        )
        run_in_catalog(resource)
        expect_file_mode(target_file, "640")
      end
    end

    context "which is managed" do
      it "should not override the mode" do
        file_res = Puppet::Type.type(:file).new(
          :name   => target_file,
          :ensure => :present
        )
        nag_res = Puppet::Type.type(:nagios_host).new(
          :name   => 'spechost',
          :use    => 'spectemplate',
          :ensure => :present,
          :target => target_file,
          :mode   => '0640'
        )
        run_in_catalog(file_res, nag_res)
        expect_file_mode(target_file, initial_mode.to_s(8))
      end
    end
  end
end
