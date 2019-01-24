require 'spec_helper'

require 'puppet/indirector/report/processor'

describe Puppet::Transaction::Report::Processor do
  before do
    allow(Puppet.settings).to receive(:use).and_return(true)
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
    allow(Puppet.settings).to receive(:use)
    @reporter = Puppet::Transaction::Report::Processor.new
    @request = double('request', :instance => double("report", :host => 'hostname'), :key => 'node')
  end

  it "should not save the report if reports are set to 'none'" do
    expect(Puppet::Reports).not_to receive(:report)
    Puppet[:reports] = 'none'

    request = Puppet::Indirector::Request.new(:indirection_name, :head, "key", nil)
    report = Puppet::Transaction::Report.new
    request.instance = report

    @reporter.save(request)
  end

  it "should save the report with each configured report type" do
    Puppet[:reports] = "one,two"
    expect(@reporter.send(:reports)).to eq(%w{one two})

    expect(Puppet::Reports).to receive(:report).with('one')
    expect(Puppet::Reports).to receive(:report).with('two')

    @reporter.save(@request)
  end

  it "should destroy reports for each processor that responds to destroy" do
    Puppet[:reports] = "http,store"
    http_report = double()
    store_report = double()
    expect(store_report).to receive(:destroy).with(@request.key)
    expect(Puppet::Reports).to receive(:report).with('http').and_return(http_report)
    expect(Puppet::Reports).to receive(:report).with('store').and_return(store_report)
    @reporter.destroy(@request)
  end
end

describe Puppet::Transaction::Report::Processor, " when processing a report" do
  before do
    Puppet[:reports] = "one"
    allow(Puppet.settings).to receive(:use)
    @reporter = Puppet::Transaction::Report::Processor.new

    @report_type = double('one')
    @dup_report = double('dupe report')
    allow(@dup_report).to receive(:process)
    @report = Puppet::Transaction::Report.new
    expect(@report).to receive(:dup).and_return(@dup_report)

    @request = double('request', :instance => @report)

    expect(Puppet::Reports).to receive(:report).with("one").and_return(@report_type)

    expect(@dup_report).to receive(:extend).with(@report_type)
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
    expect(@dup_report).to receive(:process)
    @reporter.save(@request)
  end

  it "should not raise exceptions" do
    Puppet[:trace] = false
    expect(@dup_report).to receive(:process).and_raise(ArgumentError)
    expect { @reporter.save(@request) }.not_to raise_error
  end
end
