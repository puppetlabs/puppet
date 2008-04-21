#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-3-7.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/key/ca'

describe Puppet::SSL::Key::Ca do
    it "should have documentation" do
        Puppet::SSL::Key::Ca.doc.should be_instance_of(String)
    end

    it "should store the ca key at the :cakey location" do
        Puppet.settings.stubs(:use)
        Puppet.settings.stubs(:value).returns "whatever"
        Puppet.settings.stubs(:value).with(:cakey).returns "/ca/key"
        file = Puppet::SSL::Key::Ca.new
        file.stubs(:ca?).returns true
        file.path("whatever").should == "/ca/key"
    end

    describe "when choosing the path for the public key" do
        it "should fail if the key is not for the CA" do
            Puppet.settings.stubs(:use)
            Puppet.settings.stubs(:value).returns "whatever"
            Puppet.settings.stubs(:value).with(:cakey).returns "/ca/key"
            file = Puppet::SSL::Key::Ca.new
            file.stubs(:ca?).returns false
            lambda { file.path("whatever") }.should raise_error(ArgumentError)
        end
    end
end
