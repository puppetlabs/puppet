#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-3-7.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/certificate/file'

describe Puppet::SSL::Certificate::File do
    it "should have documentation" do
        Puppet::SSL::Certificate::File.doc.should be_instance_of(String)
    end

    it "should use the :certdir as the collection directory" do
        Puppet.settings.expects(:value).with(:certdir).returns "/cert/dir"
        Puppet::SSL::Certificate::File.collection_directory.should == "/cert/dir"
    end
end
