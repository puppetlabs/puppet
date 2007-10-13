#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-23.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/code/report'

describe Puppet::Indirector::Code::Report do
    it "should provide a method for saving reports" do
        Puppet::Indirector::Code::Report.new.should respond_to(:save)
    end
end


describe Puppet::Indirector::Code::Report, " when saving a report" do
    before do
        Puppet.settings.stubs(:use)
        @reporter = Puppet::Indirector::Code::Report.new
    end

    it "should not process the report if reports are set to 'none'" do
        Puppet::Reports.expects(:report).never
        Puppet.settings.expects(:value).with(:reports).returns("none")

        @reporter.save(:whatever)
    end

    it "should process the report with each configured report type" do
        Puppet.settings.stubs(:value).with(:reports).returns("one,two")
        @reporter.send(:reports).should == %w{one two}
    end
end

describe Puppet::Indirector::Code::Report, " when processing a report" do
    before do
        Puppet.settings.stubs(:value).with(:reports).returns("one")
        Puppet.settings.stubs(:use)
        @reporter = Puppet::Indirector::Code::Report.new

        @report_type = mock 'one'
        @dup_report = mock 'dupe report'
        @dup_report.stubs(:process)
        @report = mock 'report'
        @report.expects(:dup).returns(@dup_report)
        Puppet::Reports.expects(:report).with("one").returns(@report_type)

        @dup_report.expects(:extend).with(@report_type)
    end

    # LAK:NOTE This is stupid, because the code is so short it doesn't
    # make sense to split it out, which means I just do the same test
    # three times so the spec looks right.
    it "should process a duplicate of the report, not the original" do
        @reporter.save(@report)
    end

    it "should extend the report with the report type's module" do
        @reporter.save(@report)
    end

    it "should call the report type's :process method" do
        @dup_report.expects(:process)
        @reporter.save(@report)
    end

    it "should not raise exceptions" do
        Puppet.settings.stubs(:value).with(:trace).returns(false)
        @dup_report.expects(:process).raises(ArgumentError)
        proc { @reporter.save(@report) }.should_not raise_error
    end
end
