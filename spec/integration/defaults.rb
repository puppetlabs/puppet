#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/defaults'

describe "Puppet defaults" do
    after { Puppet.settings.clear }

    describe "when setting the :factpath" do
        it "should add the :factpath to Facter's search paths" do
            Facter.expects(:search).with("/my/fact/path")

            Puppet.settings[:factpath] = "/my/fact/path"
        end
    end

    describe "when setting the :certname" do
        it "should fail if the certname is not downcased" do
            lambda { Puppet.settings[:certname] = "Host.Domain.Com" }.should raise_error(ArgumentError)
        end
    end

    describe "when configuring the :crl" do
        it "should warn if :cacrl is set to false" do
            Puppet.expects(:warning)
            Puppet.settings[:cacrl] = 'false'
        end
    end
end
