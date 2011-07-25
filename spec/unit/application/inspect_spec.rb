#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/application/inspect'
require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/yaml'
require 'puppet/indirector/report/rest'
require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::Application::Inspect do
  include PuppetSpec::Files

  before :each do
    @inspect = Puppet::Application[:inspect]
    @inspect.preinit
  end

  it "should operate in agent run_mode" do
    @inspect.class.run_mode.name.should == :agent
  end

  describe "during setup" do
    it "should print its configuration if asked" do
      Puppet[:configprint] = "all"

      Puppet.settings.expects(:print_configs).returns(true)
      expect { @inspect.setup }.to exit_with 0
    end

    it "should fail if reporting is turned off" do
      Puppet[:report] = false
      lambda { @inspect.setup }.should raise_error(/report=true/)
    end
  end

  describe "when executing" do
    before :each do
      Puppet[:report] = true
      @inspect.options[:logset] = true
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

    it "should set audited to true for all events" do
      catalog = Puppet::Resource::Catalog.new
      file = Tempfile.new("foo")
      resource = Puppet::Resource.new(:file, file.path, :parameters => {:audit => "all"})
      catalog.add_resource(resource)
      Puppet::Resource::Catalog::Yaml.any_instance.stubs(:find).returns(catalog)

      events = nil

      Puppet::Transaction::Report::Rest.any_instance.expects(:save).with do |request|
        events = request.instance.resource_statuses.values.first.events
      end

      @inspect.run_command

      events.each do |event|
        event.audited.should == true
      end
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

    describe "when archiving to a bucket" do
      before :each do
        Puppet[:archive_files] = true
        Puppet[:archive_file_server] = "filebucketserver"
        @catalog = Puppet::Resource::Catalog.new
        Puppet::Resource::Catalog::Yaml.any_instance.stubs(:find).returns(@catalog)
      end

      describe "when auditing files" do
        before :each do
          @file = tmpfile("foo")
          @resource = Puppet::Resource.new(:file, @file, :parameters => {:audit => "content"})
          @catalog.add_resource(@resource)
        end

        it "should send an existing file to the file bucket" do
          File.open(@file, 'w') { |f| f.write('stuff') }
          Puppet::FileBucketFile::Rest.any_instance.expects(:head).with do |request|
            request.server == Puppet[:archive_file_server]
          end.returns(false)
          Puppet::FileBucketFile::Rest.any_instance.expects(:save).with do |request|
            request.server == Puppet[:archive_file_server] and request.instance.contents == 'stuff'
          end
          @inspect.run_command
        end

        it "should not send unreadable files" do
          File.open(@file, 'w') { |f| f.write('stuff') }
          File.chmod(0, @file)
          Puppet::FileBucketFile::Rest.any_instance.expects(:head).never
          Puppet::FileBucketFile::Rest.any_instance.expects(:save).never
          @inspect.run_command
        end

        it "should not try to send non-existent files" do
          Puppet::FileBucketFile::Rest.any_instance.expects(:head).never
          Puppet::FileBucketFile::Rest.any_instance.expects(:save).never
          @inspect.run_command
        end

        it "should not try to send files whose content we are not auditing" do
          @resource[:audit] = "group"
          Puppet::FileBucketFile::Rest.any_instance.expects(:head).never
          Puppet::FileBucketFile::Rest.any_instance.expects(:save).never
          @inspect.run_command
        end

        it "should continue if bucketing a file fails" do
          File.open(@file, 'w') { |f| f.write('stuff') }
          Puppet::FileBucketFile::Rest.any_instance.stubs(:head).returns false
          Puppet::FileBucketFile::Rest.any_instance.stubs(:save).raises "failure"
          Puppet::Transaction::Report::Rest.any_instance.expects(:save).with do |request|
            @report = request.instance
          end

          @inspect.run_command

          @report.logs.first.should_not == nil
          @report.logs.first.message.should =~ /Could not back up/
        end
      end

      describe "when auditing non-files" do
        before :each do
          Puppet::Type.newtype(:stub_type) do
            newparam(:name) do
              desc "The name var"
              isnamevar
            end

            newproperty(:content) do
              desc "content"
              def retrieve
                :whatever
              end
            end
          end

          @resource = Puppet::Resource.new(:stub_type, 'foo', :parameters => {:audit => "all"})
          @catalog.add_resource(@resource)
        end

        after :each do
          Puppet::Type.rmtype(:stub_type)
        end

        it "should not try to send non-files" do
          Puppet::FileBucketFile::Rest.any_instance.expects(:head).never
          Puppet::FileBucketFile::Rest.any_instance.expects(:save).never
          @inspect.run_command
        end
      end
    end

    describe "when there are failures" do
      before :each do
        Puppet::Type.newtype(:stub_type) do
          newparam(:name) do
            desc "The name var"
            isnamevar
          end

          newproperty(:content) do
            desc "content"
            def retrieve
              raise "failed"
            end
          end
        end

        @catalog = Puppet::Resource::Catalog.new
        Puppet::Resource::Catalog::Yaml.any_instance.stubs(:find).returns(@catalog)

        Puppet::Transaction::Report::Rest.any_instance.expects(:save).with do |request|
          @report = request.instance
        end
      end

      after :each do
        Puppet::Type.rmtype(:stub_type)
      end

      it "should mark the report failed and create failed events for each property" do
        @resource = Puppet::Resource.new(:stub_type, 'foo', :parameters => {:audit => "all"})
        @catalog.add_resource(@resource)

        @inspect.run_command

        @report.status.should == "failed"
        @report.logs.select{|log| log.message =~ /Could not inspect/}.size.should == 1
        @report.resource_statuses.size.should == 1
        @report.resource_statuses['Stub_type[foo]'].events.size.should == 1

        event = @report.resource_statuses['Stub_type[foo]'].events.first
        event.property.should == "content"
        event.status.should == "failure"
        event.audited.should == true
        event.instance_variables.should_not include("@previous_value")
      end

      it "should continue to the next resource" do
        @resource = Puppet::Resource.new(:stub_type, 'foo', :parameters => {:audit => "all"})
        @other_resource = Puppet::Resource.new(:stub_type, 'bar', :parameters => {:audit => "all"})
        @catalog.add_resource(@resource)
        @catalog.add_resource(@other_resource)

        @inspect.run_command

        @report.resource_statuses.size.should == 2
        @report.resource_statuses.keys.should =~ ['Stub_type[foo]', 'Stub_type[bar]']
      end
    end
  end

  after :all do
    Puppet::Resource::Catalog.indirection.reset_terminus_class
    Puppet::Transaction::Report.indirection.terminus_class = :processor
  end
end
