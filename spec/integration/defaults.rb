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

    it "should have a clientyamldir setting" do
        Puppet.settings[:clientyamldir].should_not be_nil
    end

    it "should have different values for the yamldir and clientyamldir" do
        Puppet.settings[:yamldir].should_not == Puppet.settings[:clientyamldir]
    end

    # See #1232
    it "should not specify a user or group for the clientyamldir" do
        Puppet.settings.element(:clientyamldir).owner.should be_nil
        Puppet.settings.element(:clientyamldir).group.should be_nil
    end

    # See #1232
    it "should not specify a user or group for the rundir" do
        Puppet.settings.element(:rundir).owner.should be_nil
        Puppet.settings.element(:rundir).group.should be_nil
    end
end
