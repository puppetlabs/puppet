#!/usr/bin/env ruby
#
#  Created by David Schmitt on 2007-09-13
#  Copyright (c) 2007. All rights reserved.

$:.unshift("../../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestDebianServiceProvider < Test::Unit::TestCase
    include PuppetTest
    include Puppet::Util

    def prepare_provider(servicename, output)
        @resource = mock 'resource'
        @resource.stubs(:[]).with(:name).returns("myresource")
        provider = Puppet::Type.type(:service).provider(:debian).new(@resource)

        provider.stubs(:update).returns(output)

        provider
    end

    def assert_enabled( servicename, output)
        provider = prepare_provider( servicename, output )
        assert_equal(:true, provider.enabled?,
                     "Service provider=debian thinks service is disabled, when it isn't")
    end

    def assert_disabled( servicename, output )
        provider = prepare_provider( servicename, output )
        assert_equal(:false, provider.enabled?,
                     "Service provider=debian thinks service is enabled, when it isn't")
    end

    # Testing #822
    def test_file_rc
        # These messages are from file-rc's
        # update-rc.d -n -f $service remove
        assert_enabled("test1", "/etc/runlevel.tmp not installed as /etc/runlevel.conf\n")
        assert_disabled("test2", "Nothing to do.\n")
    end

    def test_sysv_rc
        # These messages are from file-rc's
        # update-rc.d -n -f $service remove
        assert_enabled("test3", """ Removing any system startup links for /etc/init.d/test3 ...
    /etc/rc0.d/K11test3
    /etc/rc1.d/K11test3
    /etc/rc2.d/S89test3
    /etc/rc3.d/S89test3
    /etc/rc4.d/S89test3
    /etc/rc5.d/S89test3
    /etc/rc6.d/K11test3
""")
        assert_disabled("test4", " Removing any system startup links for /etc/init.d/test4 ...\n")
    end
end
