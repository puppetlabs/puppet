#!/usr/bin/env ruby

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

    def check_for_users
        count = Puppet::Type.type(:user).inject(0) { |c,o|
            c + 1
        }
        assert(count > 0, "Found no users")
    end

    def check_to_transportable(config)
        trans = nil
        assert_nothing_raised("Could not convert to a transportable") {
            trans = config.to_transportable
        }

        comp = nil
        assert_nothing_raised("Could not convert transportable to component") {
            comp = trans.to_type
        }

        check_for_users()

        assert_nothing_raised("Could not retrieve transported config") {
            comp.retrieve
        }
    end

    def check_to_manifest(config)
        manifest = nil
        assert_nothing_raised("Could not convert to a manifest") {
            manifest = config.to_manifest
        }

        Puppet[:parseonly] = true
        parser = Puppet::Parser::Parser.new()

        objects = nil
        assert_nothing_raised("Could not parse generated manifest") {
            parser.string = manifest
            objects = parser.parse
        }
        scope = Puppet::Parser::Scope.new
        assert_nothing_raised("Could not compile objects") {
            scope.evaluate(:ast => objects)
        }
        trans = nil
        assert_nothing_raised("Could not convert objects to transportable") {
            trans = scope.to_trans
        }
        assert_nothing_raised("Could not instantiate objects") {
            trans.to_type
        }
        check_for_users()
    end

    def check_to_comp(config)
        comp = nil
        assert_nothing_raised("Could not convert to a component") {
            comp = config.to_component
        }

        assert_nothing_raised("Could not retrieve component") {
            comp.retrieve
        }

        check_for_users()
    end

    def check_to_config(config)
        newc = config.dup

        newfile = tempfile()
        File.open(newfile, "w") { |f| f.print config.to_config }
        assert_nothing_raised("Could not parse generated configuration") {
            newc.parse(newfile)
        }

        assert_equal(config, newc, "Configurations are not equal")
    end

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
            c.setdefaults(:testing, :booltest => [true, "testing"])
        }

        assert(c[:booltest])
        c = mkconfig

        assert_nothing_raised {
            c.setdefaults(:testing, :booltest => ["true", "testing"])
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
            c.setdefaults(:testing, :strtest => [val, "testing"])
        }

        assert_equal(val, c[:strtest])

        # Verify that variables are interpolated
        assert_nothing_raised {
            c.setdefaults(:testing, :another => ["another $strtest", "testing"])
        }

        assert_equal("another #{val}", c[:another])
    end

    def test_files
        c = mkconfig

        parent = "/puppet"
        assert_nothing_raised {
            c.setdefaults(:testing, :parentdir => [parent, "booh"])
        }

        assert_nothing_raised {
            c.setdefaults(:testing, :child => ["$parent/child", "rah"])
        }

        assert_equal(parent, c[:parentdir])
        assert_equal("/puppet/child", File.join(c[:parentdir], "child"))
    end

    def test_getset
        c = mkconfig
        initial = "an initial value"
        assert_raise(Puppet::Error) {
            c[:yayness] = initial
        }

        default = "this is a default"
        assert_nothing_raised {
            c.setdefaults(:testing, :yayness => [default, "rah"])
        }

        assert_equal(default, c[:yayness])

        assert_nothing_raised {
            c[:yayness] = initial
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
owner = root
group = root
yay = /a/path

[section1]
    attr = value
    owner = puppet
    group = puppet
    attrdir = /some/dir
    attr3 = $attrdir/other
        }

        file = tempfile()
        File.open(file, "w") { |f| f.puts text }

        c = mkconfig
        assert_nothing_raised {
            c.setdefaults("puppet",
                :one => ["a", "one"],
                :two => ["a", "two"],
                :yay => ["/default/path", "boo"],
                :mkusers => [true, "uh, yeah"]
            )
        }

        assert_nothing_raised {
            c.setdefaults("section1",
                :attr => ["a", "one"],
                :attrdir => ["/another/dir", "two"],
                :attr3 => ["$attrdir/maybe", "boo"]
            )
        }
        
        assert_nothing_raised {
            c.parse(file)
        }

        assert_equal("value", c[:attr])
        assert_equal("/some/dir", c[:attrdir])
        assert_equal(:directory, c.element(:attrdir).type)
        assert_equal("/some/dir/other", c[:attr3])

        elem = nil
        assert_nothing_raised {
            elem = c.element(:attr3)
        }

        assert(elem)
        assert_equal("puppet", elem.owner)

        config = nil
        assert_nothing_raised {
            config = c.to_config
        }

        assert_nothing_raised("Could not create transportable config") {
            c.to_transportable
        }

        check_to_comp(c)
        Puppet::Type.allclear
        check_to_manifest(c)
        Puppet::Type.allclear
        check_to_config(c)
        Puppet::Type.allclear
        check_to_transportable(c)
    end

    def test_arghandling
        c = mkconfig

        assert_nothing_raised {
            c.setdefaults("testing",
                :onboolean => [true, "An on bool"],
                :offboolean => [false, "An off bool"],
                :string => ["a string", "A string arg"],
                :file => ["/path/to/file", "A file arg"]
            )
        }

        data = {
            :onboolean => [true, false],
            :offboolean => [true, false],
            :string => ["one string", "another string"],
            :file => %w{/a/file /another/file}
        }
        data.each { |param, values|
            values.each { |val|
                opt = nil
                arg = nil
                if c.boolean?(param)
                    if val
                        opt = "--%s" % param
                    else
                        opt = "--no-%s" % param
                    end
                else
                    opt = "--%s" % param
                    arg = val
                end

                assert_nothing_raised("Could not handle arg %s with value %s" %
                    [opt, val]) {

                    c.handlearg(opt, arg)
                }
            }
        }
    end

    def test_argadding
        c = mkconfig

        assert_nothing_raised {
            c.setdefaults("testing",
                :onboolean => [true, "An on bool"],
                :offboolean => [false, "An off bool"],
                :string => ["a string", "A string arg"],
                :file => ["/path/to/file", "A file arg"]
            )
        }
        options = []

        c.addargs(options)

        c.each { |param, obj|
            opt = "--%s" % param
            assert(options.find { |ary|
                ary[0] == opt
            }, "Argument %s was not added" % opt)

            if c.boolean?(param)
                o = "--no-%s" % param
                assert(options.find { |ary|
                ary[0] == o
                }, "Boolean off %s was not added" % o)
            end
        }
    end

    def test_usesection
        c = mkconfig

        dir = tempfile()
        file = "$mydir/myfile"
        realfile = File.join(dir, "myfile")
        otherfile = File.join(dir, "otherfile")
        section = "testing"
        assert_nothing_raised {
            c.setdefaults(section,
                :mydir => [dir, "A dir arg"],
                :otherfile => {
                    :default => "$mydir/otherfile",
                    :create => true,
                    :desc => "A file arg"
                },
                :myfile => [file, "A file arg"]
            )
        }

        assert_nothing_raised("Could not use a section") {
            c.use(section)
        }

        assert_nothing_raised("Could not reuse a section") {
            c.use(section)
        }

        assert(FileTest.directory?(dir), "Did not create directory")
        assert(FileTest.exists?(otherfile), "Did not create file")
        assert(!FileTest.exists?(realfile), "Created file")
    end

    def test_setdefaultsarray
        c = mkconfig

        assert_nothing_raised {
            c.setdefaults("yay",
                :a => [false, "some value"],
                :b => ["/my/file", "a file"]
            )
        }

        assert_equal(false, c[:a], "Values are not equal")
        assert_equal("/my/file", c[:b], "Values are not equal")
    end

    def test_setdefaultshash
        c = mkconfig

        assert_nothing_raised {
            c.setdefaults("yay",
                :a => {:default => false, :desc => "some value"},
                :b => {:default => "/my/file", :desc => "a file"}
            )
        }

        assert_equal(false, c[:a], "Values are not equal")
        assert_equal("/my/file", c[:b], "Values are not equal")
    end

    def test_reuse
        c = mkconfig

        file = tempfile()
        section = "testing"
        assert_nothing_raised {
            c.setdefaults(section,
                :myfile => {:default => file, :create => true}
            )
        }

        assert_nothing_raised("Could not use a section") {
            c.use(section)
        }

        assert(FileTest.exists?(file), "Did not create file")

        assert(! Puppet::Type.type(:file)[file], "File obj still exists")

        File.unlink(file)

        c.reuse
        assert(FileTest.exists?(file), "Did not create file")
    end

    def test_mkusers
        c = mkconfig

        file = tempfile()
        section = "testing"
        assert_nothing_raised {
            c.setdefaults(section,
                :mkusers => [false, "yay"],
                :myfile => {
                    :default => file,
                    :owner => "pptest",
                    :group => "pptest",
                    :create => true
                }
            )
        }

        comp = nil
        assert_nothing_raised {
            comp = c.to_component
        }

        [:user, :group].each do |type|
            # The objects might get created internally by Puppet::Util; just
            # make sure they're not being managed
            if obj = Puppet.type(type)["pptest"]
                assert(! obj.managed?, "%s objectis managed" % type)
            end
        end
        comp.each { |o| o.remove }

        c[:mkusers] = true

        assert_nothing_raised {
            c.to_component
        }

        assert(Puppet.type(:user)["pptest"], "User object did not get created")
        assert(Puppet.type(:user)["pptest"].managed?,
            "User object is not managed."
        )
        assert(Puppet.type(:group)["pptest"], "Group object did not get created")
        assert(Puppet.type(:group)["pptest"].managed?,
            "Group object is not managed."
        )
    end

    def test_notmanagingdev
        c = mkconfig
        path = "/dev/testing"
        c.setdefaults(:test,
            :file => {
                :default => path,
                :mode => 0640,
                :desc => 'yay'
            }
        )

        assert_nothing_raised {
            c.to_component
        }

        assert(! Puppet.type(:file)["/dev/testing"], "Created dev file")
    end
end

# $Id$
