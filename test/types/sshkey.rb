# Test key job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'puppet/type/parsedtype/sshkey'
require 'test/unit'
require 'facter'

class TestSSHKey < Test::Unit::TestCase
	include TestPuppet
    def setup
        super
        # god i'm lazy
        @sshtype = Puppet.type(:sshkey)
        @oldfiletype = @sshtype.filetype
    end

    def teardown
        @sshtype.filetype = @oldfiletype
        Puppet.type(:file).clear
        super
    end

    # Here we just create a fake key type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        @sshtype.filetype = Puppet::FileType.filetype(:ram)
    end

    def mkkey
        key = nil

        if defined? @kcount
            @kcount += 1
        else
            @kcount = 1
        end

        assert_nothing_raised {
            key = @sshtype.create(
                :name => "host%s.madstop.com" % @kcount,
                :key => "%sAAAAB3NzaC1kc3MAAACBAMnhSiku76y3EGkNCDsUlvpO8tRgS9wL4Eh54WZfQ2lkxqfd2uT/RTT9igJYDtm/+UHuBRdNGpJYW1Nw2i2JUQgQEEuitx4QKALJrBotejGOAWxxVk6xsh9xA0OW8Q3ZfuX2DDitfeC8ZTCl4xodUMD8feLtP+zEf8hxaNamLlt/AAAAFQDYJyf3vMCWRLjTWnlxLtOyj/bFpwAAAIEAmRxxXb4jjbbui9GYlZAHK00689DZuX0EabHNTl2yGO5KKxGC6Esm7AtjBd+onfu4Rduxut3jdI8GyQCIW8WypwpJofCIyDbTUY4ql0AQUr3JpyVytpnMijlEyr41FfIb4tnDqnRWEsh2H7N7peW+8DWZHDFnYopYZJ9Yu4/jHRYAAACAERG50e6aRRb43biDr7Ab9NUCgM9bC0SQscI/xdlFjac0B/kSWJYTGVARWBDWug705hTnlitY9cLC5Ey/t/OYOjylTavTEfd/bh/8FkAYO+pWdW3hx6p97TBffK0b6nrc6OORT2uKySbbKOn0681nNQh4a6ueR3JRppNkRPnTk5c=" % @kcount,
                :type => "ssh-dss",
                :alias => ["192.168.0.%s" % @kcount]
            )
        }

        return key
    end

    def test_simplekey
        mkfaketype
        assert_nothing_raised {
            assert_nil(Puppet.type(:sshkey).retrieve)
        }

        key = mkkey

        assert_apply(key)

        assert_nothing_raised {
            Puppet.type(:sshkey).store
        }

        assert_nothing_raised {
            assert(
                Puppet.type(:sshkey).to_file.include?(
                    Puppet.type(:sshkey).fileobj.read
                ),
                "File does not include all of our objects"
            )
        }
    end

    def test_keysparse
        fakedata("data/types/sshkey").each { |file|
            @sshtype.path = file
            assert_nothing_raised {
                @sshtype.retrieve
            }
            @sshtype.clear
        }
    end

    def test_moddingkey
        mkfaketype
        key = mkkey()

        assert_events([:sshkey_created], key)

        key.retrieve

        key[:alias] = %w{madstop kirby yayness}

        Puppet.err :mark
        assert_events([:sshkey_changed], key)
    end

    def test_aliasisstate
        assert_equal(:state, @sshtype.attrtype(:alias))
    end

    def test_multivalues
        key = mkkey
        assert_raise(Puppet::Error) {
            key[:alias] = "puppetmasterd yayness"
        }
    end

    def test_puppetalias
        key = mkkey()

        assert_nothing_raised {
            key[:alias] = "testing"
        }

        same = key.class["testing"]
        assert(same, "Could not retrieve by alias")
    end

    def test_removal
        mkfaketype
        sshkey = mkkey()
        assert_nothing_raised {
            sshkey[:ensure] = :present
        }
        assert_events([:sshkey_created], sshkey)

        sshkey.retrieve
        assert(sshkey.insync?)
        assert_nothing_raised {
            sshkey[:ensure] = :absent
        }

        assert_events([:sshkey_removed], sshkey)
        sshkey.retrieve
        assert_events([], sshkey)
    end

    def test_modifyingfile
        keyfile = tempfile()
        Puppet.type(:sshkey).path = keyfile

        keys = []
        names = []
        3.times {
            k = mkkey()
            #h[:ensure] = :present
            #h.retrieve
            keys << k
            names << k.name
        }
        assert_apply(*keys)
        keys.clear
        Puppet.type(:sshkey).clear
        newkey = mkkey()
        #newkey[:ensure] = :present
        names << newkey.name
        assert_apply(newkey)
        Puppet.type(:sshkey).clear
        # Verify we can retrieve that info
        assert_nothing_raised("Could not retrieve after second write") {
            newkey.retrieve
        }

        # And verify that we have data for everything
        names.each { |name|
            key = Puppet.type(:sshkey)[name]
            assert(key)
            assert(key[:type])
        }
    end
end

# $Id$
