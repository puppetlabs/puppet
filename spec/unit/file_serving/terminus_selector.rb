#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/terminus_selector'

describe Puppet::FileServing::TerminusSelector, " when being used to select termini" do
    before do
        @object = Object.new
        @object.extend(Puppet::FileServing::TerminusSelector)
    end

    it "should choose :rest when the protocol is 'puppet'" do
        @object.select_terminus("puppet://host/module/file").should == :rest
    end

    it "should choose :local when the protocol is 'file'" do
        @object.select_terminus("file://host/module/file").should == :local
    end

    it "should choose :local when the URI is a normal path name" do
        @object.select_terminus("/module/file").should == :local
    end

    it "should fail when a protocol other than :puppet or :file is used" do
        proc { @object.select_terminus("http:///module/file") }.should raise_error(ArgumentError)
    end
end
