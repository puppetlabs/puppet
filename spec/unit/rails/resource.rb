#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe "Puppet::Rails::Resource" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    def column(name, type)
        ActiveRecord::ConnectionAdapters::Column.new(name, nil, type, false)
    end

    before do
        require 'puppet/rails/resource'

        # Stub this so we don't need access to the DB.
        Puppet::Rails::Resource.stubs(:columns).returns([column("title", "string"), column("restype", "string"), column("exported", "boolean")])
    end

    describe "when creating initial resource arguments" do
        it "should set the restype to the resource's type" do
            Puppet::Rails::Resource.rails_resource_initial_args(Puppet::Resource.new(:file, "/file"))[:restype].should == "File"
        end

        it "should set the title to the resource's title" do
            Puppet::Rails::Resource.rails_resource_initial_args(Puppet::Resource.new(:file, "/file"))[:title].should == "/file"
        end

        it "should set the line to the resource's line if one is available" do
            resource = Puppet::Resource.new(:file, "/file")
            resource.line = 50

            Puppet::Rails::Resource.rails_resource_initial_args(resource)[:line].should == 50
        end

        it "should set 'exported' to true of the resource is exported" do
            resource = Puppet::Resource.new(:file, "/file")
            resource.exported = true

            Puppet::Rails::Resource.rails_resource_initial_args(resource)[:exported].should be_true
        end
    end
end
