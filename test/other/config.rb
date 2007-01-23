#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/config'
require 'puppettest'
require 'puppettest/parsertesting'

class TestConfig < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting

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

        interp = nil
        assert_nothing_raised do
            interp = mkinterp :Code => manifest, :UseNodes => false
        end

        trans = nil
        assert_nothing_raised do
            trans = interp.evaluate(nil, {})
        end
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
        # We want to make sure that config processes do not result in graphing.
        Puppet[:graphdir] = tempfile()
        Puppet[:graph] = true
        Dir.mkdir(Puppet[:graphdir])
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
        
        # Make sure it didn't graph anything, which is the only real way
        # to test that the transaction was marked as a configurator.
        assert(Dir.entries(Puppet[:graphdir]).reject { |f| f =~ /^\.\.?$/ }.empty?, "Graphed config process")

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
                :myfile => {:default => file, :create => true, :desc => "yay"}
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
                    :desc => "yay",
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

        user = Puppet.type(:user)["pptest"]
        assert(user, "User object did not get created")
        assert(user.managed?, "User object is not managed.")
        assert(user.should(:comment), "user does not have a comment set")
        
        group = Puppet.type(:group)["pptest"]
        assert(group, "Group object did not get created")
        assert(group.managed?,
            "Group object is not managed."
        )
        
        if Process.uid == 0
            cleanup do
                user[:ensure] = :absent
                group[:ensure] = :absent
                assert_apply(user, group)
            end
            
            assert_apply(user, group)
        end
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

    def test_groupsetting
        cfile = tempfile()

        group = "yayness"

        File.open(cfile, "w") do |f|
            f.puts "[#{Puppet.name}]
            group = #{group}
            "
        end

        config = mkconfig
        config.setdefaults(Puppet.name, :group => ["puppet", "a group"])

        assert_nothing_raised {
            config.parse(cfile)
        }

        assert_equal(group, config[:group], "Group did not take")
    end

    # provide a method to modify and create files w/out specifying the info
    # already stored in a config
    def test_writingfiles
        path = tempfile()
        mode = 0644

        config = mkconfig

        args = { :default => path, :mode => mode, :desc => "yay" }

        user = nonrootuser()
        group = nonrootgroup()

        if Puppet::SUIDManager.uid == 0
            args[:owner] = user.name
            args[:group] = group.name
        end

        config.setdefaults(:testing, :myfile => args)

        assert_nothing_raised {
            config.write(:myfile) do |file|
                file.puts "yay"
            end
        }

        assert_equal(mode, filemode(path), "Modes are not equal")

        # OS X is broken in how it chgrps files 
        if Puppet::SUIDManager.uid == 0
            assert_equal(user.uid, File.stat(path).uid, "UIDS are not equal")

            case Facter["operatingsystem"].value
            when /BSD/, "Darwin": # nothing
            else
                assert_equal(group.gid, File.stat(path).gid, "GIDS are not equal")
            end
        end
    end

    def test_mkdir
        path = tempfile()
        mode = 0755

        config = mkconfig

        args = { :default => path, :mode => mode, :desc => "a file" }

        user = nonrootuser()
        group = nonrootgroup()

        if Puppet::SUIDManager.uid == 0
            args[:owner] = user.name
            args[:group] = group.name
        end

        config.setdefaults(:testing, :mydir => args)

        assert_nothing_raised {
            config.mkdir(:mydir)
        }

        assert_equal(mode, filemode(path), "Modes are not equal")


        # OS X and *BSD is broken in how it chgrps files 
        if Puppet::SUIDManager.uid == 0
            assert_equal(user.uid, File.stat(path).uid, "UIDS are not equal")

            case Facter["operatingsystem"].value
            when /BSD/, "Darwin": # nothing
            else
                assert_equal(group.gid, File.stat(path).gid, "GIDS are not equal")
            end
        end
    end

    def test_booleans_and_integers
        config = mkconfig
        config.setdefaults(:mysection,
            :booltest => [false, "yay"],
            :inttest => [14, "yay"]
        )

        file = tempfile()

        File.open(file, "w") do |f|
            f.puts %{
[mysection]
booltest = true
inttest = 27
}
        end

        assert_nothing_raised {
            config.parse(file)
        }

        assert_equal(true, config[:booltest], "Boolean was not converted")
        assert_equal(27, config[:inttest], "Integer was not converted")

        # Now make sure that they get converted through handlearg
        config.handlearg("--inttest", "true")
        assert_equal(true, config[:inttest], "Boolean was not converted")
        config.handlearg("--no-booltest", "false")
        assert_equal(false, config[:booltest], "Boolean was not converted")
    end

    # Make sure that tags are ignored when configuring
    def test_configs_ignore_tags
        config = mkconfig
        file = tempfile()

        config.setdefaults(:mysection,
            :mydir => [file, "a file"]
        )

        Puppet[:tags] = "yayness"

        assert_nothing_raised {
            config.use(:mysection)
        }

        assert(FileTest.directory?(file), "Directory did not get created")

        assert_equal("yayness", Puppet[:tags],
            "Tags got changed during config")
    end

    def test_configs_replace_in_url
        config = mkconfig
        
        config.setdefaults(:mysection, :name => ["yayness", "yay"])
        config.setdefaults(:mysection, :url => ["http://$name/rahness", "yay"])

        val = nil
        assert_nothing_raised {
            val = config[:url]
        }

        assert_equal("http://yayness/rahness", val,
            "Config got messed up")
    end

    def test_correct_type_assumptions
        config = mkconfig

        file = Puppet::Config::CFile
        element = Puppet::Config::CElement
        bool = Puppet::Config::CBoolean

        # We have to keep these ordered, unfortunately.
        [
            ["/this/is/a/file", file],
            ["true", bool],
            [true, bool],
            ["false", bool],
            ["server", element],
            ["http://$server/yay", element],
            ["$server/yayness", file],
            ["$server/yayness.conf", file]
        ].each do |ary|
            value, type = ary
            elem = nil
            assert_nothing_raised {
                elem = config.newelement(
                    :name => value,
                    :default => value,
                    :desc => name.to_s,
                    :section => :yayness
                )
            }

            assert_instance_of(type, elem,
                "%s got created as wrong type" % value.inspect)
        end
    end

    # Make sure we correctly reparse our config files but don't lose CLI values.
    def test_reparse
        Puppet[:filetimeout] = 0

        config = mkconfig()
        config.setdefaults(:mysection, :default => ["default", "yay"])
        config.setdefaults(:mysection, :clichange => ["clichange", "yay"])
        config.setdefaults(:mysection, :filechange => ["filechange", "yay"])

        file = tempfile()
        # Set one parameter in the file
        File.open(file, "w") { |f|
            f.puts %{[mysection]\nfilechange = filevalue}
        }
        assert_nothing_raised {
            config.parse(file)
        }

        # Set another "from the cli"
        assert_nothing_raised {
            config.handlearg("clichange", "clivalue")
        }

        # And leave the other unset
        assert_equal("default", config[:default])
        assert_equal("filevalue", config[:filechange])
        assert_equal("clivalue", config[:clichange])

        # Now rewrite the file
        File.open(file, "w") { |f|
            f.puts %{[mysection]\nfilechange = newvalue}
        }

        cfile = config.file
        cfile.send("tstamp=".intern, Time.now - 50)

        # And check all of the values
        assert_equal("default", config[:default])
        assert_equal("clivalue", config[:clichange])
        assert_equal("newvalue", config[:filechange])
    end

    def test_parse_removes_quotes
        config = mkconfig()
        config.setdefaults(:mysection, :singleq => ["single", "yay"])
        config.setdefaults(:mysection, :doubleq => ["double", "yay"])
        config.setdefaults(:mysection, :none => ["noquote", "yay"])
        config.setdefaults(:mysection, :middle => ["midquote", "yay"])

        file = tempfile()
        # Set one parameter in the file
        File.open(file, "w") { |f|
            f.puts %{[mysection]\n
    singleq = 'one'
    doubleq = "one"
    none = one
    middle = mid"quote
}
        }

        assert_nothing_raised {
            config.parse(file)
        }

        %w{singleq doubleq none}.each do |p|
            assert_equal("one", config[p], "%s did not match" % p)
        end
        assert_equal('mid"quote', config["middle"], "middle did not match")
    end

    def test_timer
        Puppet[:filetimeout] = 0.1
        origpath = tempfile()
        config = mkconfig()
        config.setdefaults(:mysection, :paramdir => [tempfile(), "yay"])

        file = tempfile()
        # Set one parameter in the file
        File.open(file, "w") { |f|
            f.puts %{[mysection]\n
    paramdir = #{origpath}
}
        }

        assert_nothing_raised {
            config.parse(file)
            config.use(:mysection)
        }

        assert(FileTest.directory?(origpath), "dir did not get created")

        # Now start the timer
        assert_nothing_raised {
            EventLoop.current.monitor_timer config.timer
        }

        newpath = tempfile()

        File.open(file, "w") { |f|
            f.puts %{[mysection]\n
    paramdir = #{newpath}
}
        }
        config.file.send("tstamp=".intern, Time.now - 50)
        sleep 1

        assert_equal(newpath, config["paramdir"],
                    "File did not get reparsed from timer")
        assert(FileTest.directory?(newpath), "new dir did not get created")


    end

    # Test that config parameters correctly call passed-in blocks when the value
    # is set.
    def test_paramblocks
        config = mkconfig()

        testing = nil
        elem = nil
        assert_nothing_raised do
            elem = config.newelement :default => "yay",
                :name => :blocktest,
                :desc => "boo",
                :section => :test,
                :hook => proc { |value| testing = value }
        end

        assert_nothing_raised do
            assert_equal("yay", elem.value)
        end

        assert_nothing_raised do
            elem.value = "yaytest"
        end

        assert_nothing_raised do
            assert_equal("yaytest", elem.value)
        end
        assert_equal("yaytest", testing)

        assert_nothing_raised do
            elem.value = "another"
        end

        assert_nothing_raised do
            assert_equal("another", elem.value)
        end
        assert_equal("another", testing)

        # Now verify it works from setdefault
        assert_nothing_raised do
            config.setdefaults :test,
                :blocktest2 => {
                    :default => "yay",
                    :desc => "yay",
                    :hook => proc { |v| testing = v }
                }
        end

        assert_equal("yay", config[:blocktest2])

        assert_nothing_raised do
            config[:blocktest2] = "footest"
        end
        assert_equal("footest", config[:blocktest2])
        assert_equal("footest", testing)
    end

    def test_no_modify_root
        config = mkconfig
        config.setdefaults(:yay,
            :mydir => {:default => tempfile(),
                :mode => 0644,
                :owner => "root",
                :group => "root",
                :desc => "yay"
            },
            :mkusers => [false, "yay"]
        )

        assert_nothing_raised do
            config.use(:yay)
        end

        # Now enable it so they'll be added
        config[:mkusers] = true

        comp = config.to_component

        Puppet::Type.type(:user).each do |u|
            assert(u.name != "root", "Tried to manage root user")
        end
        Puppet::Type.type(:group).each do |u|
            assert(u.name != "root", "Tried to manage root group")
            assert(u.name != "wheel", "Tried to manage wheel group")
        end

#        assert(yay, "Did not find yay component")
#        yay.each do |c|
#            puts c.ref
#        end
#        assert(! yay.find { |o| o.class.name == :user and o.name == "root" },
#            "Found root user")
#        assert(! yay.find { |o| o.class.name == :group and o.name == "root" },
#            "Found root group")
    end
    
    # #415
    def test_remove_trailing_spaces
        config = mkconfig()
        config.setdefaults(:yay, :rah => ["testing", "a desc"])
        
        file = tempfile()
        File.open(file, "w") { |f| f.puts "rah = something " }
        
        assert_nothing_raised { config.parse(file) }
        assert_equal("something", config[:rah], "did not remove trailing whitespace in parsing")
    end
end

# $Id$
