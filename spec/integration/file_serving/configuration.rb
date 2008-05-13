#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/configuration'

describe Puppet::FileServing::Configuration, " when finding files with Puppet::FileServing::Mount" do
    before do
        # Just in case it already exists.
        Puppet::Util::Cacher.invalidate

        @mount = Puppet::FileServing::Mount.new("mymount")
        FileTest.stubs(:exists?).with("/my/path").returns(true)
        FileTest.stubs(:readable?).with("/my/path").returns(true)
        FileTest.stubs(:directory?).with("/my/path").returns(true)
        @mount.path = "/my/path"

        FileTest.stubs(:exists?).with(Puppet[:fileserverconfig]).returns(true)
        @parser = mock 'parser'
        @parser.stubs(:parse).returns("mymount" => @mount)
        @parser.stubs(:changed?).returns(true)
        Puppet::FileServing::Configuration::Parser.stubs(:new).returns(@parser)

        @config = Puppet::FileServing::Configuration.create
    end

    it "should return nil if the file does not exist" do
        FileTest.expects(:exists?).with("/my/path/my/file").returns(false)
        @config.file_path("/mymount/my/file").should be_nil
    end

    it "should return the full file path if the file exists" do
        FileTest.expects(:exists?).with("/my/path/my/file").returns(true)
        @config.file_path("/mymount/my/file").should == "/my/path/my/file"
    end

    after do
        Puppet::Util::Cacher.invalidate
    end
end
