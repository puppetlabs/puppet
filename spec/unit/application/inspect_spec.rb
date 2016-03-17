#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/application/inspect'
require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/json'
require 'puppet/indirector/report/rest'
require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::Application::Inspect do
  include PuppetSpec::Files

  before :each do
    @inspect = Puppet::Application[:inspect]
    @inspect.preinit
  end

  it "should operate in agent run_mode" do
    expect(@inspect.class.run_mode.name).to eq(:agent)
  end

  describe "during setup" do
    it "should print its configuration if asked" do
      Puppet[:configprint] = "all"

      Puppet.settings.expects(:print_configs).returns(true)
      expect { @inspect.setup }.to exit_with 0
    end

    it "should fail if reporting is turned off" do
      Puppet[:report] = false
      expect { @inspect.setup }.to raise_error(/report=true/)
    end

    it "should default to the json terminus class when catalog_cache_terminus is not set" do
      Puppet::Resource::Catalog.indirection.expects(:terminus_class=).with(:json)
      expect { @inspect.setup }.not_to raise_error
    end

    it "should respect the catalog_cache_terminus if set" do
      Puppet[:catalog_cache_terminus] = :yaml
      Puppet::Resource::Catalog.indirection.expects(:terminus_class=).with(:yaml)
      expect { @inspect.setup }.not_to raise_error
    end
  end

  describe "when executing", :uses_checksums => true do
    before :each do
      Puppet[:report] = true
      @inspect.options[:setdest] = true
      Puppet::Transaction::Report::Rest.any_instance.stubs(:save)
      @inspect.setup
    end

    it "should retrieve the local catalog" do
      Puppet::Resource::Catalog::Json.any_instance.expects(:find).with {|request| request.key == Puppet[:certname] }.returns(Puppet::Resource::Catalog.new)

      @inspect.run_command
    end

    it "should save the report to REST" do
      Puppet::Resource::Catalog::Json.any_instance.stubs(:find).returns(Puppet::Resource::Catalog.new)
      Puppet::Transaction::Report::Rest.any_instance.expects(:save).with {|request| request.instance.host == Puppet[:certname] }

      @inspect.run_command
    end

    with_digest_algorithms do
      it "should audit the specified properties" do
        catalog = Puppet::Resource::Catalog.new
        file = Tempfile.new("foo")
        file.binmode
        file.print plaintext
        file.close
        resource = Puppet::Resource.new(:file, file.path, :parameters => {:audit => "all"})
        catalog.add_resource(resource)
        Puppet::Resource::Catalog::Json.any_instance.stubs(:find).returns(catalog)

        events = nil

        Puppet::Transaction::Report::Rest.any_instance.expects(:save).with do |request|
          events = request.instance.resource_statuses.values.first.events
        end

        @inspect.run_command

        properties = events.inject({}) do |property_values, event|
          property_values.merge(event.property => event.previous_value)
        end
        expect(properties["ensure"]).to eq(:file)
        expect(properties["content"]).to eq("{#{digest_algorithm}}#{checksum}")
        expect(properties.has_key?("target")).to eq(false)
      end
    end

    it "should set audited to true for all events" do
      catalog = Puppet::Resource::Catalog.new
      file = Tempfile.new("foo")
      resource = Puppet::Resource.new(:file, file.path, :parameters => {:audit => "all"})
      catalog.add_resource(resource)
      Puppet::Resource::Catalog::Json.any_instance.stubs(:find).returns(catalog)

      events = nil

      Puppet::Transaction::Report::Rest.any_instance.expects(:save).with do |request|
        events = request.instance.resource_statuses.values.first.events
      end

      @inspect.run_command

      events.each do |event|
        expect(event.audited).to eq(true)
      end
    end

    it "should not report irrelevent attributes if the resource is absent" do
      catalog = Puppet::Resource::Catalog.new
      file = Tempfile.new("foo")
      resource = Puppet::Resource.new(:file, file.path, :parameters => {:audit => "all"})
      file.close
      file.delete
      catalog.add_resource(resource)
      Puppet::Resource::Catalog::Json.any_instance.stubs(:find).returns(catalog)

      events = nil

      Puppet::Transaction::Report::Rest.any_instance.expects(:save).with do |request|
        events = request.instance.resource_statuses.values.first.events
      end

      @inspect.run_command

      properties = events.inject({}) do |property_values, event|
        property_values.merge(event.property => event.previous_value)
      end
      expect(properties).to eq({"ensure" => :absent})
    end

    describe "when archiving to a bucket" do
      before :each do
        Puppet[:archive_files] = true
        Puppet[:archive_file_server] = "filebucketserver"
        @catalog = Puppet::Resource::Catalog.new
        Puppet::Resource::Catalog::Json.any_instance.stubs(:find).returns(@catalog)
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

        it "should not send unreadable files", :unless => (Puppet.features.microsoft_windows? || Puppet.features.root?) do
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

          expect(@report.logs.first).not_to eq(nil)
          expect(@report.logs.first.message).to match(/Could not back up/)
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
        Puppet::Resource::Catalog::Json.any_instance.stubs(:find).returns(@catalog)

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

        expect(@report.status).to eq("failed")
        expect(@report.logs.select{|log| log.message =~ /Could not inspect/}.size).to eq(1)
        expect(@report.resource_statuses.size).to eq(1)
        expect(@report.resource_statuses['Stub_type[foo]'].events.size).to eq(1)

        event = @report.resource_statuses['Stub_type[foo]'].events.first
        expect(event.property).to eq("content")
        expect(event.status).to eq("failure")
        expect(event.audited).to eq(true)
        expect(event.instance_variables).not_to include "@previous_value"
        expect(event.instance_variables).not_to include :@previous_value
      end

      it "should continue to the next resource" do
        @resource = Puppet::Resource.new(:stub_type, 'foo', :parameters => {:audit => "all"})
        @other_resource = Puppet::Resource.new(:stub_type, 'bar', :parameters => {:audit => "all"})
        @catalog.add_resource(@resource)
        @catalog.add_resource(@other_resource)

        @inspect.run_command

        expect(@report.resource_statuses.size).to eq(2)
        expect(@report.resource_statuses.keys).to match_array(['Stub_type[foo]', 'Stub_type[bar]'])
      end
    end
  end

  after :all do
    Puppet::Resource::Catalog.indirection.reset_terminus_class
    Puppet::Transaction::Report.indirection.terminus_class = :processor
  end
end
