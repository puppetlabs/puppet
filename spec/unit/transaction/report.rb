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

    describe "when accepting events" do
        before do
            @report = Puppet::Transaction::Report.new
        end

        it "should add each event to its event list" do
            event = stub 'event'
            @report.register_event event
            @report.events.should be_include(event)
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
end

describe Puppet::Transaction::Report, " when computing exit status" do
    it "should compute 2 if changes present" do
        report = Puppet::Transaction::Report.new
        report.newmetric("changes", {:total => 1})
        report.newmetric("resources", {:failed => 0})
        report.exit_status.should == 2
    end

    it "should compute 4 if failures present" do
        report = Puppet::Transaction::Report.new
        report.newmetric("changes", {:total => 0})
        report.newmetric("resources", {:failed => 1})
        report.exit_status.should == 4
    end

    it "should compute 6 if both changes and present" do
        report = Puppet::Transaction::Report.new
        report.newmetric("changes", {:total => 1})
        report.newmetric("resources", {:failed => 1})
        report.exit_status.should == 6
    end
end
