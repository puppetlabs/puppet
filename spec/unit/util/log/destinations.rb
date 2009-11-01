#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/util/log'

describe Puppet::Util::Log.desttypes[:report] do
    before do
        @dest = Puppet::Util::Log.desttypes[:report]
    end

    it "should require a report at initialization" do
        @dest.new("foo").report.should == "foo"
    end

    it "should send new messages to the report" do
        report = mock 'report'
        dest = @dest.new(report)

        report.expects(:<<).with("my log")

        dest.handle "my log"
    end
end
