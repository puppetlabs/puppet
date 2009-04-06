#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe "Puppet::Rails::Host" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    def column(name, type)
        ActiveRecord::ConnectionAdapters::Column.new(name, nil, type, false)
    end

    before do
        require 'puppet/rails/host'

        # Stub this so we don't need access to the DB.
        Puppet::Rails::Host.stubs(:columns).returns([column("name", "string"), column("environment", "string"), column("ip", "string")])

        @node = Puppet::Node.new("foo")
        @node.environment = "production"
        @node.ipaddress = "127.0.0.1"

        @host = stub 'host', :environment= => nil, :ip= => nil
    end

    describe "when converting a Puppet::Node instance into a Rails instance" do
        it "should modify any existing instance in the database" do
            Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

            Puppet::Rails::Host.from_puppet(@node)
        end

        it "should create a new instance in the database if none can be found" do
            Puppet::Rails::Host.expects(:find_by_name).with("foo").returns nil
            Puppet::Rails::Host.expects(:new).with(:name => "foo").returns @host

            Puppet::Rails::Host.from_puppet(@node)
        end

        it "should copy the environment from the Puppet instance" do
            Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

            @node.environment = "production"
            @host.expects(:environment=).with "production"

            Puppet::Rails::Host.from_puppet(@node)
        end

        it "should copy the ipaddress from the Puppet instance" do
            Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

            @node.ipaddress = "192.168.0.1"
            @host.expects(:ip=).with "192.168.0.1"

            Puppet::Rails::Host.from_puppet(@node)
        end

        it "should not save the Rails instance" do
            Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

            @host.expects(:save).never

            Puppet::Rails::Host.from_puppet(@node)
        end
    end

    describe "when converting a Puppet::Rails::Host instance into a Puppet::Node instance" do
        before do
            @host = Puppet::Rails::Host.new(:name => "foo", :environment => "production", :ip => "127.0.0.1")
            @node = Puppet::Node.new("foo")
            Puppet::Node.stubs(:new).with("foo").returns @node
        end

        it "should create a new instance with the correct name" do
            Puppet::Node.expects(:new).with("foo").returns @node

            @host.to_puppet
        end

        it "should copy the environment from the Rails instance" do
            @host.environment = "prod"
            @node.expects(:environment=).with "prod"
            @host.to_puppet
        end

        it "should copy the ipaddress from the Rails instance" do
            @host.ip = "192.168.0.1"
            @node.expects(:ipaddress=).with "192.168.0.1"
            @host.to_puppet
        end
    end
end
