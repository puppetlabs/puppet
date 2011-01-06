#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/inspect'
require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/yaml'
require 'puppet/indirector/report/rest'

describe Puppet::Application::Inspect do
  before :each do
    @inspect = Puppet::Application[:inspect]
  end

  describe "during setup" do
    it "should print its configuration if asked" do
      Puppet[:configprint] = "all"

      Puppet.settings.expects(:print_configs).returns(true)
      lambda { @inspect.setup }.should raise_error(SystemExit)
    end

    it "should fail if reporting is turned off" do
      Puppet[:report] = false
      lambda { @inspect.setup }.should raise_error(/report=true/)
    end
  end

  describe "when executing" do
    before :each do
      Puppet[:report] = true
      Puppet::Util::Log.stubs(:newdestination)
      Puppet::Transaction::Report::Rest.any_instance.stubs(:save)
      @inspect.setup
    end

    it "should retrieve the local catalog" do
      Puppet::Resource::Catalog::Yaml.any_instance.expects(:find).with {|request| request.key == Puppet[:certname] }.returns(Puppet::Resource::Catalog.new)

      @inspect.run_command
    end

    it "should save the report to REST" do
      Puppet::Resource::Catalog::Yaml.any_instance.stubs(:find).returns(Puppet::Resource::Catalog.new)
      Puppet::Transaction::Report::Rest.any_instance.expects(:save).with {|request| request.instance.host == Puppet[:certname] }

      @inspect.run_command
    end

    it "should audit the specified properties" do
      catalog = Puppet::Resource::Catalog.new
      file = Tempfile.new("foo")
      file.puts("file contents")
      file.close
      resource = Puppet::Resource.new(:file, file.path, :parameters => {:audit => "all"})
      catalog.add_resource(resource)
      Puppet::Resource::Catalog::Yaml.any_instance.stubs(:find).returns(catalog)

      events = nil

      Puppet::Transaction::Report::Rest.any_instance.expects(:save).with do |request|
        events = request.instance.resource_statuses.values.first.events
      end

      @inspect.run_command

      properties = events.inject({}) do |property_values, event|
        property_values.merge(event.property => event.previous_value)
      end
      properties["ensure"].should == :file
      properties["content"].should == "{md5}#{Digest::MD5.hexdigest("file contents\n")}"
      properties.has_key?("target").should == false
    end

    it "should not report irrelevent attributes if the resource is absent" do
      catalog = Puppet::Resource::Catalog.new
      file = Tempfile.new("foo")
      resource = Puppet::Resource.new(:file, file.path, :parameters => {:audit => "all"})
      file.delete
      catalog.add_resource(resource)
      Puppet::Resource::Catalog::Yaml.any_instance.stubs(:find).returns(catalog)

      events = nil

      Puppet::Transaction::Report::Rest.any_instance.expects(:save).with do |request|
        events = request.instance.resource_statuses.values.first.events
      end

      @inspect.run_command

      properties = events.inject({}) do |property_values, event|
        property_values.merge(event.property => event.previous_value)
      end
      properties.should == {"ensure" => :absent}
    end
  end

  after :all do
    Puppet::Resource::Catalog.indirection.reset_terminus_class
    Puppet::Transaction::Report.indirection.terminus_class = :processor
  end
end
