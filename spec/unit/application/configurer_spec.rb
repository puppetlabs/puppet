#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/configurer'
require 'puppet/indirector/catalog/rest'
require 'puppet/indirector/report/rest'
require 'tempfile'

describe "Puppet::Application::Configurer" do
  it "should retrieve and apply a catalog and submit a report" do
    dirname = Dir.mktmpdir("puppetdir")
    Puppet[:vardir]   = dirname
    Puppet[:confdir]  = dirname
    Puppet[:certname] = "foo"
    @catalog = Puppet::Resource::Catalog.new
    @file = Puppet::Resource.new(:file, File.join(dirname, "tmp_dir_resource"), :parameters => {:ensure => :present})
    @catalog.add_resource(@file)

    @report = Puppet::Transaction::Report.new("apply")
    Puppet::Transaction::Report.stubs(:new).returns(@report)

    Puppet::Resource::Catalog::Rest.any_instance.stubs(:find).returns(@catalog)
    @report.expects(:save)

    Puppet::Util::Log.stubs(:newdestination)

    Puppet::Application::Configurer.new.run

    @report.status.should == "changed"
  end
end
