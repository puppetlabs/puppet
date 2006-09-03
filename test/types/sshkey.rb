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
        @sshkeytype = Puppet.type(:sshkey)

        @provider = @sshkeytype.defaultprovider

        # Make sure they aren't using something funky like netinfo
        unless @provider.name == :parsed
            @sshkeytype.defaultprovider = @sshkeytype.provider(:parsed)
        end

        cleanup do @sshkeytype.defaultprovider = nil end

        oldpath = @provider.path
        cleanup do
            @provider.path = oldpath
        end
        @provider.path = tempfile()
    end

    def mkkey
        key = nil

        if defined? @kcount
            @kcount += 1
        else
            @kcount = 1
        end

        assert_nothing_raised {
            key = @sshkeytype.create(
                :name => "host%s.madstop.com" % @kcount,
                :key => "%sAAAAB3NzaC1kc3MAAACBAMnhSiku76y3EGkNCDsUlvpO8tRgS9wL4Eh54WZfQ2lkxqfd2uT/RTT9igJYDtm/+UHuBRdNGpJYW1Nw2i2JUQgQEEuitx4QKALJrBotejGOAWxxVk6xsh9xA0OW8Q3ZfuX2DDitfeC8ZTCl4xodUMD8feLtP+zEf8hxaNamLlt/AAAAFQDYJyf3vMCWRLjTWnlxLtOyj/bFpwAAAIEAmRxxXb4jjbbui9GYlZAHK00689DZuX0EabHNTl2yGO5KKxGC6Esm7AtjBd+onfu4Rduxut3jdI8GyQCIW8WypwpJofCIyDbTUY4ql0AQUr3JpyVytpnMijlEyr41FfIb4tnDqnRWEsh2H7N7peW+8DWZHDFnYopYZJ9Yu4/jHRYAAACAERG50e6aRRb43biDr7Ab9NUCgM9bC0SQscI/xdlFjac0B/kSWJYTGVARWBDWug705hTnlitY9cLC5Ey/t/OYOjylTavTEfd/bh/8FkAYO+pWdW3hx6p97TBffK0b6nrc6OORT2uKySbbKOn0681nNQh4a6ueR3JRppNkRPnTk5c=" % @kcount,
                :type => "ssh-dss",
                :alias => ["192.168.0.%s" % @kcount]
            )
        }

        return key
    end

    def test_simplekey
        assert_nothing_raised {
            Puppet.type(:sshkey).defaultprovider.retrieve

            count = 0
            @sshkeytype.each do |h|
                count += 1
            end

            assert_equal(0, count, "Found sshkeys in empty file somehow")
        }

        key = mkkey

        assert_apply(key)

        assert(key.exists?, "Key did not get created")
    end

    def test_moddingkey
        key = mkkey()

        assert_events([:sshkey_created], key)

        key.retrieve

        key[:alias] = %w{madstop kirby yayness}

        assert_events([:sshkey_changed], key)
    end

    def test_aliasisstate
        assert_equal(:state, @sshkeytype.attrtype(:alias))
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
        sshkey = mkkey()
        assert_nothing_raised {
            sshkey[:ensure] = :present
        }
        assert_events([:sshkey_created], sshkey)

        assert(sshkey.exists?, "key was not created")
        assert_nothing_raised {
            sshkey[:ensure] = :absent
        }

        assert_events([:sshkey_deleted], sshkey)
        assert(! sshkey.exists?, "Key was not deleted")
        assert_events([], sshkey)
    end

    def test_modifyingfile
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

        # Verify we can retrieve that info
        assert_nothing_raised("Could not retrieve after second write") {
            newkey.retrieve
        }

        # And verify that we have data for everything
        names.each { |name|
            key = Puppet.type(:sshkey)[name] || Puppet.type(:sshkey).create(:name => name)
            assert(key)
            assert(key.exists?, "key %s is missing" % name)
        }
    end
end

# $Id$
