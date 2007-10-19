#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

describe "Puppet::Indirector::FileServerMounts", :shared => true do
    # This only works if the shared behaviour is included before
    # the 'before' block in the including context.
    before do
        Puppet::FileServing::Configuration.clear_cache
        FileTest.stubs(:exists?).with(Puppet[:fileserverconfig]).returns(true)
        FileTest.stubs(:exists?).with("/my/mount/path").returns(true)
        FileTest.stubs(:directory?).with("/my/mount/path").returns(true)
        FileTest.stubs(:readable?).with("/my/mount/path").returns(true)

        # Use a real mount, so the integration is a bit deeper.
        @mount1 = Puppet::FileServing::Configuration::Mount.new("one")
        @mount1.path = "/my/mount/path"

        @parser = stub 'parser', :changed? => false
        @parser.stubs(:parse).returns("one" => @mount1)

        Puppet::FileServing::Configuration::Parser.stubs(:new).returns(@parser)

        Puppet::FileServing::Configuration.create.stubs(:modules_mount)
    end

    it "should use the file server configuration to find files" do
        path = "/my/mount/path/my/file"
        FileTest.stubs(:exists?).with(path).returns(true)
        @test_class.expects(:new).with(path).returns(:myinstance)
        FileTest.stubs(:exists?).with("/my/mount/path").returns(true)
        @mount1.expects(:file).with("my/file", {}).returns(path)

        @terminus.find("puppetmounts://myhost/one/my/file").should == :myinstance
    end
end
