#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/transaction/report'

describe Puppet::Transaction::Report do
  include PuppetSpec::Files
  before do
    Puppet::Util::Storage.stubs(:store)
  end

  it "should set its host name to the node_name_value" do
    Puppet[:node_name_value] = 'mynode'
    Puppet::Transaction::Report.new("apply").host.should == "mynode"
  end

  it "should return its host name as its name" do
    r = Puppet::Transaction::Report.new("apply")
    r.name.should == r.host
  end

  it "should create an initialization timestamp" do
    Time.expects(:now).returns "mytime"
    Puppet::Transaction::Report.new("apply").time.should == "mytime"
  end

  it "should take a 'kind' as an argument" do
    Puppet::Transaction::Report.new("inspect").kind.should == "inspect"
  end

  it "should take a 'configuration_version' as an argument" do
    Puppet::Transaction::Report.new("inspect", "some configuration version").configuration_version.should == "some configuration version"
  end

  it "should be able to set configuration_version" do
    report = Puppet::Transaction::Report.new("inspect")
    report.configuration_version = "some version"
    report.configuration_version.should == "some version"
  end

  it "should not include whits" do
    Puppet::FileBucket::File.indirection.stubs(:save)

    filename = tmpfile('whit_test')
    file = Puppet::Type.type(:file).new(:path => filename)

    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource(file)

    report = Puppet::Transaction::Report.new("apply")

    catalog.apply(:report => report)
    report.finalize_report

    report.resource_statuses.values.any? {|res| res.resource_type =~ /whit/i}.should be_false
    report.metrics['time'].values.any? {|metric| metric.first =~ /whit/i}.should be_false
  end

  describe "when accepting logs" do
    before do
      @report = Puppet::Transaction::Report.new("apply")
    end

    it "should add new logs to the log list" do
      @report << "log"
      @report.logs[-1].should == "log"
    end

    it "should return self" do
      r = @report << "log"
      r.should equal(@report)
    end
  end

  describe "when accepting resource statuses" do
    before do
      @report = Puppet::Transaction::Report.new("apply")
    end

    it "should add each status to its status list" do
      status = stub 'status', :resource => "foo"
      @report.add_resource_status status
      @report.resource_statuses["foo"].should equal(status)
    end
  end

  describe "when using the indirector" do
    it "should redirect :save to the indirection" do
      Facter.stubs(:value).returns("eh")
      @indirection = stub 'indirection', :name => :report
      Puppet::Transaction::Report.stubs(:indirection).returns(@indirection)
      report = Puppet::Transaction::Report.new("apply")
      @indirection.expects(:save)
      Puppet::Transaction::Report.indirection.save(report)
    end

    it "should default to the 'processor' terminus" do
      Puppet::Transaction::Report.indirection.terminus_class.should == :processor
    end

    it "should delegate its name attribute to its host method" do
      report = Puppet::Transaction::Report.new("apply")
      report.expects(:host).returns "me"
      report.name.should == "me"
    end

    after do
      Puppet::Util::Cacher.expire
    end
  end

  describe "when computing exit status" do
    it "should produce 2 if changes are present" do
      report = Puppet::Transaction::Report.new("apply")
      report.add_metric("changes", {"total" => 1})
      report.add_metric("resources", {"failed" => 0})
      report.exit_status.should == 2
    end

    it "should produce 4 if failures are present" do
      report = Puppet::Transaction::Report.new("apply")
      report.add_metric("changes", {"total" => 0})
      report.add_metric("resources", {"failed" => 1})
      report.exit_status.should == 4
    end

    it "should produce 6 if both changes and failures are present" do
      report = Puppet::Transaction::Report.new("apply")
      report.add_metric("changes", {"total" => 1})
      report.add_metric("resources", {"failed" => 1})
      report.exit_status.should == 6
    end
  end

  describe "before finalizing the report" do
    it "should have a status of 'failed'" do
      report = Puppet::Transaction::Report.new("apply")
      report.status.should == 'failed'
    end
  end

  describe "when finalizing the report" do
    before do
      @report = Puppet::Transaction::Report.new("apply")
    end

    def metric(name, value)
      if metric = @report.metrics[name.to_s]
        metric[value]
      else
        nil
      end
    end

    def add_statuses(count, type = :file)
      count.times do |i|
        status = Puppet::Resource::Status.new(Puppet::Type.type(type).new(:title => "/my/path#{i}"))
        yield status if block_given?
        @report.add_resource_status status
      end
    end


    [:time, :resources, :changes, :events].each do |type|
      it "should add #{type} metrics" do
        @report.finalize_report
        @report.metrics[type.to_s].should be_instance_of(Puppet::Transaction::Metric)
      end
    end

    describe "for resources" do
      it "should provide the total number of resources" do
        add_statuses(3)

        @report.finalize_report
        metric(:resources, "total").should == 3
      end

      Puppet::Resource::Status::STATES.each do |state|
        it "should provide the number of #{state} resources as determined by the status objects" do
          add_statuses(3) { |status| status.send(state.to_s + "=", true) }

          @report.finalize_report
          metric(:resources, state.to_s).should == 3
        end
      end

      it "should mark the report as 'failed' if there are failing resources" do
        add_statuses(1) { |status| status.failed = true }
        @report.finalize_report
        @report.status.should == 'failed'
      end
    end

    describe "for changes" do
      it "should provide the number of changes from the resource statuses and mark the report as 'changed'" do
        add_statuses(3) { |status| 3.times { status << Puppet::Transaction::Event.new(:status => 'success') } }
        @report.finalize_report
        metric(:changes, "total").should == 9
        @report.status.should == 'changed'
      end

      it "should provide a total even if there are no changes, and mark the report as 'unchanged'" do
        @report.finalize_report
        metric(:changes, "total").should == 0
        @report.status.should == 'unchanged'
      end
    end

    describe "for times" do
      it "should provide the total amount of time for each resource type" do
        add_statuses(3, :file) do |status|
          status.evaluation_time = 1
        end
        add_statuses(3, :exec) do |status|
          status.evaluation_time = 2
        end
        add_statuses(3, :mount) do |status|
          status.evaluation_time = 3
        end

        @report.finalize_report

        metric(:time, "file").should == 3
        metric(:time, "exec").should == 6
        metric(:time, "mount").should == 9
      end

      it "should add any provided times from external sources" do
        @report.add_times :foobar, 50
        @report.finalize_report
        metric(:time, "foobar").should == 50
      end

      it "should have a total time" do
        add_statuses(3, :file) do |status|
          status.evaluation_time = 1.25
        end
        @report.add_times :config_retrieval, 0.5
        @report.finalize_report
        metric(:time, "total").should == 4.25
      end
    end

    describe "for events" do
      it "should provide the total number of events" do
        add_statuses(3) do |status|
          3.times { |i| status.add_event(Puppet::Transaction::Event.new :status => 'success') }
        end
        @report.finalize_report
        metric(:events, "total").should == 9
      end

      it "should provide the total even if there are no events" do
        @report.finalize_report
        metric(:events, "total").should == 0
      end

      Puppet::Transaction::Event::EVENT_STATUSES.each do |status_name|
        it "should provide the number of #{status_name} events" do
          add_statuses(3) do |status|
            3.times do |i|
              event = Puppet::Transaction::Event.new
              event.status = status_name
              status.add_event(event)
            end
          end

          @report.finalize_report
          metric(:events, status_name).should == 9
        end
      end
    end
  end

  describe "when producing a summary" do
    before do
      resource = Puppet::Type.type(:notify).new(:name => "testing")
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource resource
      trans = catalog.apply

      @report = trans.report
      @report.finalize_report
    end

    %w{changes time resources events}.each do |main|
      it "should include the key #{main} in the raw summary hash" do
        @report.raw_summary.should be_key main
      end
    end

    it "should include the last run time in the raw summary hash" do
      Time.stubs(:now).returns(Time.utc(2010,11,10,12,0,24))
      @report.raw_summary["time"]["last_run"].should == 1289390424
    end

    %w{Changes Total Resources Time Events}.each do |main|
      it "should include information on #{main} in the textual summary" do
        @report.summary.should be_include(main)
      end
    end
  end

  describe "when outputting yaml" do
    it "should not include @external_times" do
      report = Puppet::Transaction::Report.new('apply')
      report.add_times('config_retrieval', 1.0)
      report.to_yaml_properties.should_not include('@external_times')
    end
  end
end
