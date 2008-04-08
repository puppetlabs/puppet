#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-12.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/transaction/report'

describe Puppet::Transaction::Report, " when being indirect" do
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
        Puppet::Indirector::Indirection.clear_cache
    end
end
