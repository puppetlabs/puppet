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
        Puppet::Util::Cacher.expire
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
