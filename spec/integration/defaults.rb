#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/defaults'

describe "Puppet defaults" do
    after { Puppet.settings.clear }
    describe "when configuring the :crl" do
        it "should add the :factpath to Facter's search paths" do
            Facter.expects(:search).with("/my/fact/path")

            Puppet.settings[:factpath] = "/my/fact/path"
        end
    end

    describe "when setting the :factpath" do

        it "should warn if :cacrl is set to false" do
            Puppet.expects(:warning)
            Puppet.settings[:cacrl] = 'false'
        end
    end
end
