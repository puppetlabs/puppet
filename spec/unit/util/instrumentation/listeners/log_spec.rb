require 'spec_helper'
require 'puppet/util/instrumentation'

Puppet::Util::Instrumentation.init
log = Puppet::Util::Instrumentation.listener(:log)

describe log do
  before(:each) do
    @log = log.new
  end

  it "should have a notify method" do
    @log.should respond_to(:notify)
  end

  it "should have a data method" do
    @log.should respond_to(:data)
  end

  it "should keep data for stop event" do
    @log.notify(:test, :stop, { :started => Time.at(123456789), :finished => Time.at(123456790)})
    @log.data.should == {:test=>["test took 1.0"]}
  end

  it "should not keep data for start event" do
    @log.notify(:test, :start, { :started => Time.at(123456789)})
    @log.data.should be_empty
  end

  it "should not keep more than 20 events per label" do
    25.times { @log.notify(:test, :stop, { :started => Time.at(123456789), :finished => Time.at(123456790)}) }
    @log.data[:test].size.should == 20
  end
end
