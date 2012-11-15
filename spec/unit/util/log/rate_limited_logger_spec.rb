#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/log/rate_limited_logger'

describe Puppet::Util::Log::RateLimitedLogger do

  subject { Puppet::Util::Log::RateLimitedLogger.new(60) }

  before do
    Time.stubs(:now).returns(0)
  end

  it "should be able to log all levels" do
    Puppet::Util::Log.eachlevel do |level|
      subject.should respond_to(level)
    end
  end

  it "should fail if given an invalid time interval" do
    expect { Puppet::Util::Log::RateLimitedLogger.new('foo') }.to raise_error(ArgumentError)
  end

  it "should not log the same message more than once within the given interval" do
    Puppet::Util::Log.expects(:create).once
    subject.info('foo')
    subject.info('foo')
  end

  it "should allow the same message to be logged after the given interval has passed" do
    Puppet::Util::Log.expects(:create).twice
    subject.info('foo')
    Time.stubs(:now).returns(60)
    subject.info('foo')
  end

  it "should rate-limit different message strings separately" do
    Puppet::Util::Log.expects(:create).times(3)
    subject.info('foo')
    subject.info('bar')
    subject.info('baz')
    subject.info('foo')
    subject.info('bar')
    subject.info('baz')
  end

  it "should limit the same message in different log levels independently" do
    Puppet::Util::Log.expects(:create).twice
    subject.info('foo')
    subject.warning('foo')
  end
end
