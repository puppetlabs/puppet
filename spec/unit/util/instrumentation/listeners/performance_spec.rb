require 'spec_helper'
require 'puppet/util/instrumentation'

Puppet::Util::Instrumentation.init
performance = Puppet::Util::Instrumentation.listener(:performance)

describe performance do
  before(:each) do
    @performance = performance.new
  end

  it "should have a notify method" do
    @performance.should respond_to(:notify)
  end

  it "should have a data method" do
    @performance.should respond_to(:data)
  end

  it "should keep data for stop event" do
    @performance.notify(:test, :stop, { :started => Time.at(123456789), :finished => Time.at(123456790)})
    @performance.data.should == {:test=>{:average=>1.0, :count=>1, :min=>1.0, :max=>1.0, :sum=>1.0}}
  end

  it "should accumulate performance statistics" do
    @performance.notify(:test, :stop, { :started => Time.at(123456789), :finished => Time.at(123456790)})
    @performance.notify(:test, :stop, { :started => Time.at(123456789), :finished => Time.at(123456791)})

    @performance.data.should == {:test=>{:average=>1.5, :count=>2, :min=>1.0, :max=>2.0, :sum=>3.0}}
  end

  it "should not keep data for start event" do
    @performance.notify(:test, :start, { :started => Time.at(123456789)})
    @performance.data.should be_empty
  end
end