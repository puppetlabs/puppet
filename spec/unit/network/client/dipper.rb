#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Network::Client.dipper do
    it "should fail in an informative way when there are failures backing up to the server" do
        FileTest.stubs(:exists?).returns true
        File.stubs(:read).returns "content"

        @dipper = Puppet::Network::Client::Dipper.new(:Path => "/my/bucket")

        @dipper.driver.expects(:addfile).raises ArgumentError

        lambda { @dipper.backup("/my/file") }.should raise_error(Puppet::Error)
    end
end
