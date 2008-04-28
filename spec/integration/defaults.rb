#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/defaults'

describe "Puppet defaults" do
    describe "when configuring the :crl" do
        after { Puppet.settings.clear }

        it "should have a :crl setting"  do
            Puppet.settings.should be_valid(:crl)
        end

        it "should warn if :cacrl is set to false" do
            Puppet.expects(:warning)
            Puppet.settings[:cacrl] = 'false'
        end

        it "should set :crl to 'false' if :cacrl is set to false" do
            crl = Puppet.settings[:cacrl]
            Puppet.settings[:cacrl] = 'false'
            Puppet.settings[:crl].should == false
        end
    end
end
