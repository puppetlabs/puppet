#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/report/processor'

describe Puppet::Transaction::Report::Processor do
  before do
    Puppet.settings.stubs(:use).returns(true)
  end

  it "should provide a method for saving reports" do
    expect(Puppet::Transaction::Report::Processor.new).to respond_to(:save)
  end

  it "should provide a method for cleaning reports" do
    expect(Puppet::Transaction::Report::Processor.new).to respond_to(:destroy)
  end

end

describe Puppet::Transaction::Report::Processor, " when processing a report" do
  before do
    Puppet.settings.stubs(:use)
    @reporter = Puppet::Transaction::Report::Processor.new
    @request = stub 'request', :instance => stub("report", :host => 'hostname'), :key => 'node'
  end

  it "should not save the report if reports are set to 'none'" do
    Puppet::Reports.expects(:report).never
    Puppet[:reports] = 'none'

    request = Puppet::Indirector::Request.new(:indirection_name, :head, "key", nil)
    report = Puppet::Transaction::Report.new
    request.instance = report

    @reporter.save(request)
  end

  it "should save the report with each configured report type" do
    Puppet[:reports] = "one,two"
    expect(@reporter.send(:reports)).to eq(%w{one two})

    Puppet::Reports.expects(:report).with('one')
    Puppet::Reports.expects(:report).with('two')

    @reporter.save(@request)
  end

  it "should destroy reports for each processor that responds to destroy" do
    Puppet[:reports] = "http,store"
    http_report = mock()
    store_report = mock()
    store_report.expects(:destroy).with(@request.key)
    Puppet::Reports.expects(:report).with('http').returns(http_report)
    Puppet::Reports.expects(:report).with('store').returns(store_report)
    @reporter.destroy(@request)
  end
end

describe Puppet::Transaction::Report::Processor, " when processing a report" do
  before do
    Puppet[:reports] = "one"
    Puppet.settings.stubs(:use)
    @reporter = Puppet::Transaction::Report::Processor.new

    @report_type = mock 'one'
    @dup_report = mock 'dupe report'
    @dup_report.stubs(:process)
    @report = Puppet::Transaction::Report.new
    @report.expects(:dup).returns(@dup_report)

    @request = stub 'request', :instance => @report

    Puppet::Reports.expects(:report).with("one").returns(@report_type)

    @dup_report.expects(:extend).with(@report_type)
  end

  # LAK:NOTE This is stupid, because the code is so short it doesn't
  # make sense to split it out, which means I just do the same test
  # three times so the spec looks right.
  it "should process a duplicate of the report, not the original" do
    @reporter.save(@request)
  end

  it "should extend the report with the report type's module" do
    @reporter.save(@request)
  end

  it "should call the report type's :process method" do
    @dup_report.expects(:process)
    @reporter.save(@request)
  end

  it "should not raise exceptions" do
    Puppet[:trace] = false
    @dup_report.expects(:process).raises(ArgumentError)
    expect { @reporter.save(@request) }.not_to raise_error
  end
end
