#!/usr/bin/env ruby

require 'spec_helper'
require 'puppet/file_bucket/dipper'

describe "Nagios file creation" do
  include PuppetSpec::Files

  before :each do
    FileUtils.touch(target_file)
    File.chmod(0600, target_file)
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

  # These three helpers are from file_spec.rb
  #
  # @todo Define those centrally as well?
  def get_mode(file)
    Puppet::FileSystem.stat(file).mode
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
        # sticky bit only applies to directories in Windows
        mode = Puppet.features.microsoft_windows? ? "640" : "100640"
        ( "%o" % get_mode(target_file) ).should == mode
      end
    end

    context "which is managed" do
      it "should not the mode" do
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
        ( "%o" % get_mode(target_file) ).should_not == "100640"
      end
    end

  end

end
