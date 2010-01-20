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
            report.newmetric("changes", {:total => 1})
            report.newmetric("resources", {:failed => 0})
            report.exit_status.should == 2
        end

        it "should produce 4 if failures are present" do
            report = Puppet::Transaction::Report.new
            report.newmetric("changes", {:total => 0})
            report.newmetric("resources", {:failed => 1})
            report.exit_status.should == 4
        end

        it "should produce 6 if both changes and failures are present" do
            report = Puppet::Transaction::Report.new
            report.newmetric("changes", {:total => 1})
            report.newmetric("resources", {:failed => 1})
            report.exit_status.should == 6
        end
    end
end

