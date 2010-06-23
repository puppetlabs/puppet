#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/transaction/report'

describe Puppet::Transaction::Report do
    it "should set its host name to the certname" do
        Puppet.settings.expects(:value).with(:certname).returns "myhost"
        Puppet::Transaction::Report.new.host.should == "myhost"
    end

    it "should return its host name as its name" do
        r = Puppet::Transaction::Report.new
        r.name.should == r.host
    end

    it "should create an initialization timestamp" do
        Time.expects(:now).returns "mytime"
        Puppet::Transaction::Report.new.time.should == "mytime"
    end

    describe "when accepting logs" do
        before do
            @report = Puppet::Transaction::Report.new
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
            @report = Puppet::Transaction::Report.new
        end

        it "should add each status to its status list" do
            status = stub 'status', :resource => "foo"
            @report.add_resource_status status
            @report.resource_statuses["foo"].should equal(status)
        end
    end

    describe "when using the indirector" do
        it "should redirect :find to the indirection" do
            @indirection = stub 'indirection', :name => :report
            Puppet::Transaction::Report.stubs(:indirection).returns(@indirection)
            @indirection.expects(:find)
            Puppet::Transaction::Report.find(:report)
        end

        it "should redirect :save to the indirection" do
            Facter.stubs(:value).returns("eh")
            @indirection = stub 'indirection', :name => :report
            Puppet::Transaction::Report.stubs(:indirection).returns(@indirection)
            report = Puppet::Transaction::Report.new
            @indirection.expects(:save)
            report.save
        end

        it "should default to the 'processor' terminus" do
            Puppet::Transaction::Report.indirection.terminus_class.should == :processor
        end

        it "should delegate its name attribute to its host method" do
            report = Puppet::Transaction::Report.new
            report.expects(:host).returns "me"
            report.name.should == "me"
        end

        after do
            Puppet::Util::Cacher.expire
        end
    end

    describe "when computing exit status" do
        it "should produce 2 if changes are present" do
            report = Puppet::Transaction::Report.new
            report.add_metric("changes", {:total => 1})
            report.add_metric("resources", {:failed => 0})
            report.exit_status.should == 2
        end

        it "should produce 4 if failures are present" do
            report = Puppet::Transaction::Report.new
            report.add_metric("changes", {:total => 0})
            report.add_metric("resources", {:failed => 1})
            report.exit_status.should == 4
        end

        it "should produce 6 if both changes and failures are present" do
            report = Puppet::Transaction::Report.new
            report.add_metric("changes", {:total => 1})
            report.add_metric("resources", {:failed => 1})
            report.exit_status.should == 6
        end
    end

    describe "when calculating metrics" do
        before do
            @report = Puppet::Transaction::Report.new
        end

        def metric(name, value)
            if metric = @report.metrics[name.to_s]
                metric[value]
            else
                nil
            end
        end

        def add_statuses(count, type = :file)
            3.times do |i|
                status = Puppet::Resource::Status.new(Puppet::Type.type(type).new(:title => "/my/path#{i}"))
                yield status if block_given?
                @report.add_resource_status status
            end
        end


        [:time, :resources, :changes, :events].each do |type|
            it "should add #{type} metrics" do
                @report.calculate_metrics
                @report.metrics[type.to_s].should be_instance_of(Puppet::Transaction::Metric)
            end
        end

        describe "for resources" do
            it "should provide the total number of resources" do
                add_statuses(3)

                @report.calculate_metrics
                metric(:resources, :total).should == 3
            end

            Puppet::Resource::Status::STATES.each do |state|
                it "should provide the number of #{state} resources as determined by the status objects" do
                    add_statuses(3) { |status| status.send(state.to_s + "=", true) }

                    @report.calculate_metrics
                    metric(:resources, state).should == 3
                end
            end
        end

        describe "for changes" do
            it "should provide the number of changes from the resource statuses" do
                add_statuses(3) { |status| status.change_count = 3 }
                @report.calculate_metrics
                metric(:changes, :total).should == 9
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

                @report.calculate_metrics

                metric(:time, "file").should == 3
                metric(:time, "exec").should == 6
                metric(:time, "mount").should == 9
            end

            it "should add any provided times from external sources" do
                @report.add_times :foobar, 50
                @report.calculate_metrics
                metric(:time, "foobar").should == 50
            end
        end

        describe "for events" do
            it "should provide the total number of events" do
                add_statuses(3) do |status|
                    3.times { |i| status.add_event(Puppet::Transaction::Event.new) }
                end
                @report.calculate_metrics
                metric(:events, :total).should == 9
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

                    @report.calculate_metrics
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
            @report.calculate_metrics
        end

        %w{Changes Total Resources}.each do |main|
            it "should include information on #{main} in the summary" do
                @report.summary.should be_include(main)
            end
        end
    end
end
