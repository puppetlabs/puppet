if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/config'
require 'puppettest'
require 'test/unit'

class TestConfig < Test::Unit::TestCase
	include TestPuppet

    def mkconfig
        c = nil
        assert_nothing_raised {
            c = Puppet::Config.new
        }
        return c
    end

    def test_addbools
        c = mkconfig

        assert_nothing_raised {
            c.setdefaults(:testing, :booltest => true)
        }

        assert(c[:booltest])
        c = mkconfig

        assert_nothing_raised {
            c.setdefaults(:testing, :booltest => "true")
        }

        assert(c[:booltest])

        assert_nothing_raised {
            c[:booltest] = false
        }

        assert(! c[:booltest], "Booltest is not false")

        assert_nothing_raised {
            c[:booltest] = "false"
        }

        assert(! c[:booltest], "Booltest is not false")

        assert_raise(Puppet::Error) {
            c[:booltest] = "yayness"
        }

        assert_raise(Puppet::Error) {
            c[:booltest] = "/some/file"
        }
    end

    def test_strings
        c = mkconfig
        val = "this is a string"
        assert_nothing_raised {
            c.setdefaults(:testing, :strtest => val)
        }

        assert_equal(val, c[:strtest])
    end

    def test_files
        c = mkconfig

        parent = "/puppet"
        assert_nothing_raised {
            c.setdefaults(:testing, :parentdir => parent)
        }

        assert_nothing_raised {
            c.setdefaults(:testing, :child => "$parent/child")
        }

        assert_equal(parent, c[:parentdir])
        assert_equal("/puppet/child", File.join(c[:parentdir], "child"))
    end

    def test_getset
        c = mkconfig
        initial = "an initial value"
        assert_nothing_raised {
            c[:yayness] = initial
        }
        assert_equal(initial, c[:yayness])

        default = "this is a default"
        assert_nothing_raised {
            c.setdefaults(:testing, :yayness => default)
        }

        assert_equal(initial, c[:yayness])

        assert_nothing_raised {
            c.clear
        }

        assert_equal(default, c[:yayness])

        assert_nothing_raised {
            c[:yayness] = "not default"
        }
        assert_equal("not default", c[:yayness])
    end

    def test_parse
        text = %{
one = this is a test
two = another test
user = root
group = root
yay = /a/path

[section1]
    attr = value
    user = puppet
    group = puppet
    attr2 = /some/dir
    attr3 = $attr2/other
        }

        file = tempfile()
        File.open(file, "w") { |f| f.puts text }

        c = mkconfig
        
        assert_nothing_raised {
            c.parse(file)
        }

        assert_equal("value", c[:attr])
        assert_equal("/some/dir", c[:attr2])
        assert_equal("/some/dir/other", c[:attr3])

        elem = nil
        assert_nothing_raised {
            elem = c.element(:attr3)
        }

        assert(elem)
        assert_equal("puppet", elem.user)

        puts c.to_manifest
    end
end

# $Id$
