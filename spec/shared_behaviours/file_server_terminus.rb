#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

describe "Puppet::Indirector::FileServerTerminus", :shared => true do
    # This only works if the shared behaviour is included before
    # the 'before' block in the including context.
    before do
        Puppet::Util::Cacher.invalidate
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

        # Stub out the modules terminus
        @modules = mock 'modules terminus'
    end

    it "should use the file server configuration to find files" do
        @modules.stubs(:find).returns(nil)
        @terminus.indirection.stubs(:terminus).with(:modules).returns(@modules)

        path = "/my/mount/path/my/file"
        FileTest.stubs(:exists?).with(path).returns(true)
        FileTest.stubs(:exists?).with("/my/mount/path").returns(true)
        @mount1.expects(:file).with("my/file", :node => nil).returns(path)

        @terminus.find("puppetmounts://myhost/one/my/file").should be_instance_of(@test_class)
    end
end
