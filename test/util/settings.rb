#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'mocha'
require 'puppettest'
require 'puppet/util/settings'
require 'puppettest/parsertesting'

class TestSettings < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
    CElement = Puppet::Util::Settings::CElement
    CBoolean = Puppet::Util::Settings::CBoolean

    def setup
        super
        @config = mkconfig
    end

    def set_configs(config = nil)
        config ||= @config
        config.setdefaults("main",
            :one => ["a", "one"],
            :two => ["a", "two"],
            :yay => ["/default/path", "boo"],
            :mkusers => [true, "uh, yeah"],
            :name => ["testing", "a"]
        )

        config.setdefaults("section1",
            :attr => ["a", "one"],
            :attrdir => ["/another/dir", "two"],
            :attr3 => ["$attrdir/maybe", "boo"]
        )
    end

    def check_for_users
        count = Puppet::Type.type(:user).inject(0) { |c,o|
            c + 1
        }
        assert(count > 0, "Found no users")
    end

    def test_to_transportable
        set_configs
        trans = nil
        assert_nothing_raised("Could not convert to a transportable") {
            trans = @config.to_transportable
        }

        comp = nil
        assert_nothing_raised("Could not convert transportable to component") {
            comp = trans.to_type
        }

        assert_nothing_raised("Could not retrieve transported config") {
            comp.retrieve
        }
    end

    def test_to_config
        set_configs

        newc = mkconfig
        set_configs(newc)

        # Reset all of the values, so we know they're changing.
        newc.each do |name, obj|
            next if name == :name
            newc[name] = true
        end

        newfile = tempfile()
        File.open(newfile, "w") { |f|
            @config.to_config.split("\n").each do |line|
                # Uncomment the settings, so they actually take.
                if line =~ / = /
                    f.puts line.sub(/^\s*#/, '')
                else
                    f.puts line
                end
            end
        }

        assert_nothing_raised("Could not parse generated configuration") {
            newc.parse(newfile)
        }

        @config.each do |name, object|
            assert_equal(@config[name], newc[name], "Parameter %s is not the same" % name)
        end
    end

    def mkconfig
        c = nil
        assert_nothing_raised {
            c = Puppet::Util::Settings.new
        }
        return c
    end

    def test_addbools
        assert_nothing_raised {
            @config.setdefaults(:testing, :booltest => [true, "testing"])
        }

        assert(@config[:booltest])
        @config = mkconfig

        assert_nothing_raised {
            @config.setdefaults(:testing, :booltest => ["true", "testing"])
        }

        assert(@config[:booltest])

        assert_nothing_raised {
            @config[:booltest] = false
        }

        assert(! @config[:booltest], "Booltest is not false")

        assert_nothing_raised {
            @config[:booltest] = "false"
        }

        assert(! @config[:booltest], "Booltest is not false")

        assert_raise(ArgumentError) {
            @config[:booltest] = "yayness"
        }

        assert_raise(ArgumentError) {
            @config[:booltest] = "/some/file"
        }
    end

    def test_strings
        val = "this is a string"
        assert_nothing_raised {
            @config.setdefaults(:testing, :strtest => [val, "testing"])
        }

        assert_equal(val, @config[:strtest])

        # Verify that variables are interpolated
        assert_nothing_raised {
            @config.setdefaults(:testing, :another => ["another $strtest", "testing"])
        }

        assert_equal("another #{val}", @config[:another])
    end

    def test_files
        c = mkconfig

        parent = "/puppet"
        assert_nothing_raised {
            @config.setdefaults(:testing, :parentdir => [parent, "booh"])
        }

        assert_nothing_raised {
            @config.setdefaults(:testing, :child => ["$parent/child", "rah"])
        }

        assert_equal(parent, @config[:parentdir])
        assert_equal("/puppet/child", File.join(@config[:parentdir], "child"))
    end

    def test_getset
        initial = "an initial value"
        assert_raise(ArgumentError) {
            @config[:yayness] = initial
        }

        default = "this is a default"
        assert_nothing_raised {
            @config.setdefaults(:testing, :yayness => [default, "rah"])
        }

        assert_equal(default, @config[:yayness])

        assert_nothing_raised {
            @config[:yayness] = initial
        }

        assert_equal(initial, @config[:yayness])

        assert_nothing_raised {
            @config.clear
        }

        assert_equal(default, @config[:yayness], "'clear' did not remove old values")

        assert_nothing_raised {
            @config[:yayness] = "not default"
        }
        assert_equal("not default", @config[:yayness])
    end

    def test_parse_file
        text = %{
one = this is a test
two = another test
owner = root
group = root
yay = /a/path

[main]
    four = five
    six = seven

[section1]
    attr = value
    owner = puppet
    group = puppet
    attrdir = /some/dir
    attr3 = $attrdir/other
        }

        file = tempfile()
        File.open(file, "w") { |f| f.puts text }

        @config.expects(:settimer)
        
        result = nil
        assert_nothing_raised {
            result = @config.send(:parse_file, file)
        }

        main = result[:main]
        assert(main, "Did not get section for main")
        {
            :one => "this is a test",
            :two => "another test",
            :owner => "root",
            :group => "root",
            :yay => "/a/path",
            :four => "five",
            :six => "seven"
        }.each do |param, value|
            assert_equal(value, main[param], "Param %s was not set correctly in main" % param)
        end

        section1 = result[:section1]
        assert(section1, "Did not get section1")

        {
            :attr => "value",
            :owner => "puppet",
            :group => "puppet",
            :attrdir => "/some/dir",
            :attr3 => "$attrdir/other"
        }.each do |param, value|
            assert_equal(value, section1[param], "Param %s was not set correctly in section1" % param)
        end
    end

    def test_old_parse
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

        assert_nothing_raised {
            @config.setdefaults("puppet",
                :one => ["a", "one"],
                :two => ["a", "two"],
                :yay => ["/default/path", "boo"],
                :mkusers => [true, "uh, yeah"]
            )
        }

        assert_nothing_raised {
            @config.setdefaults("section1",
                :attr => ["a", "one"],
                :attrdir => ["/another/dir", "two"],
                :attr3 => ["$attrdir/maybe", "boo"]
            )
        }
        
        assert_nothing_raised {
            @config.old_parse(file)
        }

        assert_equal("value", @config[:attr])
        assert_equal("/some/dir", @config[:attrdir])
        assert_equal(:directory, @config.element(:attrdir).type)
        assert_equal("/some/dir/other", @config[:attr3])

        elem = nil
        assert_nothing_raised {
            elem = @config.element(:attr3)
        }

        assert(elem)
        assert_equal("puppet", elem.owner)

        config = nil
        assert_nothing_raised {
            config = @config.to_config
        }

        assert_nothing_raised("Could not create transportable config") {
            @config.to_transportable
        }
    end

    def test_parse
        result = {
            :main => {:main => "main", :bad => "invalid", :cliparam => "reset"},
            :puppet => {:other => "puppet", :cliparam => "reset"},
            :puppetd => {:other => "puppetd", :cliparam => "reset"}
        }
        # Set our defaults, so they're valid. Don't define 'bad', since we want to test for failures.
        @config.setdefaults(:main,
            :main => ["whatever", "a"],
            :cliparam => ["default", "y"],
            :other => ["a", "b"],
            :name => ["puppet", "b"] # our default name
        )
        @config.setdefaults(:other,
            :one => ["whatever", "a"],
            :two => ["default", "y"],
            :apple => ["a", "b"],
            :shoe => ["puppet", "b"] # our default name
        )
        @config.handlearg("--cliparam", "changed")
        @config.stubs(:parse_file).returns(result)

        # First do it with our name being 'puppet'
        assert_nothing_raised("Could not handle parse results") do
            @config.parse(tempfile)
        end

        assert_equal(:puppet, @config.name, "Did not get correct name")
        assert_equal("main", @config[:main], "Did not get main value")
        assert_equal("puppet", @config[:other], "Did not get name value")
        assert_equal("changed", @config[:cliparam], "CLI values were overridden by config")

        # Now switch names and make sure the parsing switches, too.
        @config.clear(true)
        assert_nothing_raised("Could not handle parse results") do
            @config.parse(tempfile)
        end
        @config[:name] = :puppetd

        assert_equal(:puppetd, @config.name, "Did not get correct name")
        assert_equal("main", @config[:main], "Did not get main value")
        assert_equal("puppetd", @config[:other], "Did not get name value")
        assert_equal("changed", @config[:cliparam], "CLI values were overridden by config")
    end

    # Make sure we can extract file options correctly.
    def test_parsing_file_options
        @config.setdefaults(:whev,
            :file => {
                :desc => "whev",
                :default => "/default",
                :owner => "me",
                :group => "me",
                :mode => "755"
            }
        )

        file = tempfile
        count = 0

        {
            :pass => {
                " {owner = you}" => {:owner => "you"},
                " {owner = you, group = you}" => {:owner => "you", :group => "you"},
                " {owner = you, group = you, mode = 755}" => {:owner => "you", :group => "you", :mode => "755"},
                " { owner = you, group = you } " => {:owner => "you", :group => "you"},
                "{owner=you,group=you} " => {:owner => "you", :group => "you"},
                "{owner=you,} " => {:owner => "you"}
            },
            :fail => [
                %{{owner = you group = you}},
                %{{owner => you, group => you}},
                %{{user => you}},
                %{{random => you}},
                %{{mode => you}}, # make sure modes are numbers
                %{{owner => you}}
            ]
        }.each do |type, list|
            count += 1
            list.each do |value|
                if type == :pass
                    value, should = value[0], value[1]
                end
                path = "/other%s" % count
                # Write our file out
                File.open(file, "w") do |f|
                    f.puts %{[main]\nfile = #{path}#{value}}
                end

                if type == :fail
                    assert_raise(ArgumentError, "Did not fail on %s" % value.inspect) do
                        @config.send(:parse_file, file)
                    end
                else
                    result = nil
                    assert_nothing_raised("Failed to parse %s" % value.inspect) do
                        result = @config.send(:parse_file, file)
                    end
                    assert_equal(should, result[:main][:_meta][:file], "Got incorrect return for %s" % value.inspect)
                    assert_equal(path, result[:main][:file], "Got incorrect value for %s" % value.inspect)
                end
            end
        end
    end

    # Make sure file options returned from parse_file are handled correctly.
    def test_parsed_file_options
        @config.setdefaults(:whev,
            :file => {
                :desc => "whev",
                :default => "/default",
                :owner => "me",
                :group => "me",
                :mode => "755"
            }
        )

        result = {
            :main => {
                :file => "/other",
                :_meta => {
                    :file => {
                        :owner => "you",
                        :group => "you",
                        :mode => "644"
                    }
                }
            }
        }

        @config.expects(:parse_file).returns(result)

        assert_nothing_raised("Could not handle file options") do
            @config.parse("/whatever")
        end

        # Get the actual object, so we can verify metadata
        file = @config.element(:file)

        assert_equal("/other", @config[:file], "Did not get correct value")
        assert_equal("you", file.owner, "Did not pass on user")
        assert_equal("you", file.group, "Did not pass on group")
        assert_equal("644", file.mode, "Did not pass on mode")
    end

    def test_arghandling
        c = mkconfig

        assert_nothing_raised {
            @config.setdefaults("testing",
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
                if @config.boolean?(param)
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

                    @config.handlearg(opt, arg)
                }
            }
        }
    end

    def test_addargs
        @config.setdefaults("testing",
                            :onboolean => [true, "An on bool"],
                            :offboolean => [false, "An off bool"],
                            :string => ["a string", "A string arg"],
                            :file => ["/path/to/file", "A file arg"]
                            )

        should = []
        @config.each { |name, element|
            element.expects(:getopt_args).returns([name])
            should << name
        }
        result = []
        assert_nothing_raised("Add args failed") do
            @config.addargs(result)
        end
        assert_equal(should, result, "Did not call addargs correctly.")

    end

    def test_addargs_functional
        @config.setdefaults("testing",
                            :onboolean => [true, "An on bool"],
                            :string => ["a string", "A string arg"]
                            )
        result = []
        should = []
        assert_nothing_raised("Add args failed") do
            @config.addargs(result)
        end
        @config.each do |name, element|
            if name == :onboolean
                should << ["--onboolean", GetoptLong::NO_ARGUMENT]
                should << ["--no-onboolean", GetoptLong::NO_ARGUMENT]
            elsif name == :string
                should << ["--string", GetoptLong::REQUIRED_ARGUMENT]
            end
        end
        assert_equal(should, result, "Add args functional test failed")
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
            @config.setdefaults(section,
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
            @config.use(section)
        }

        assert_nothing_raised("Could not reuse a section") {
            @config.use(section)
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
            @config.setdefaults("yay",
                :a => [false, "some value"],
                :b => ["/my/file", "a file"]
            )
        }

        assert_equal(false, @config[:a], "Values are not equal")
        assert_equal("/my/file", @config[:b], "Values are not equal")
    end

    def test_setdefaultshash
        c = mkconfig

        assert_nothing_raised {
            @config.setdefaults("yay",
                :a => {:default => false, :desc => "some value"},
                :b => {:default => "/my/file", :desc => "a file"}
            )
        }

        assert_equal(false, @config[:a], "Values are not equal")
        assert_equal("/my/file", @config[:b], "Values are not equal")
    end

    def test_notmanagingdev
        c = mkconfig
        path = "/dev/testing"
        @config.setdefaults(:test,
            :file => {
                :default => path,
                :mode => 0640,
                :desc => 'yay'
            }
        )

        config = @config.to_configuration

        assert(! config.resource(:file, "/dev/testing"), "Created dev file")
    end

    def test_groupsetting
        cfile = tempfile()

        group = "yayness"

        File.open(cfile, "w") do |f|
            f.puts "[main]
            group = #{group}
            "
        end

        config = mkconfig
        config.setdefaults(Puppet[:name], :group => ["puppet", "a group"])

        assert_nothing_raised {
            config.parse(cfile)
        }

        assert_equal(group, config[:group], "Group did not take")
    end

    # provide a method to modify and create files w/out specifying the info
    # already stored in a config
    def test_writingfiles
        File.umask(0022)
      
        path = tempfile()
        mode = 0644

        config = mkconfig

        args = { :default => path, :mode => mode, :desc => "yay" }

        user = nonrootuser()
        group = nonrootgroup()

        if Puppet::Util::SUIDManager.uid == 0
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
        if Puppet::Util::SUIDManager.uid == 0
            assert_equal(user.uid, File.stat(path).uid, "UIDS are not equal")

            case Facter["operatingsystem"].value
            when /BSD/, "Darwin": # nothing
            else
                assert_equal(group.gid, File.stat(path).gid, "GIDS are not equal")
            end
        end
    end

    def test_mkdir
        File.umask(0022)
        
        path = tempfile()
        mode = 0755

        config = mkconfig

        args = { :default => path, :mode => mode, :desc => "a file" }

        user = nonrootuser()
        group = nonrootgroup()

        if Puppet::Util::SUIDManager.uid == 0
            args[:owner] = user.name
            args[:group] = group.name
        end

        config.setdefaults(:testing, :mydir => args)

        assert_nothing_raised {
            config.mkdir(:mydir)
        }

        assert_equal(mode, filemode(path), "Modes are not equal")


        # OS X and *BSD is broken in how it chgrps files 
        if Puppet::Util::SUIDManager.uid == 0
            assert_equal(user.uid, File.stat(path).uid, "UIDS are not equal")

            case Facter["operatingsystem"].value
            when /BSD/, "Darwin": # nothing
            else
                assert_equal(group.gid, File.stat(path).gid, "GIDS are not equal")
            end
        end
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
            "Settings got messed up")
    end

    def test_correct_type_assumptions
        config = mkconfig

        file = Puppet::Util::Settings::CFile
        element = Puppet::Util::Settings::CElement
        bool = Puppet::Util::Settings::CBoolean

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
            assert_nothing_raised {
                config.setdefaults(:yayness, value => { :default => value, :desc => name.to_s})
            }
            elem = config.element(value)

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

        config.stubs(:read_file).returns(%{[main]\nfilechange = filevalue\n})
        file = mock 'file'
        file.stubs(:changed?).returns(true)

        assert_nothing_raised {
            config.parse(file)
        }

        # Set another "from the cli"
        assert_nothing_raised {
            config.handlearg("clichange", "clivalue")
        }

        # And leave the other unset
        assert_equal("default", config[:default])
        assert_equal("filevalue", config[:filechange], "Did not get value from file")
        assert_equal("clivalue", config[:clichange])

        # Now reparse
        config.stubs(:read_file).returns(%{[main]\nfilechange = newvalue\n})
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        config.parse(file)

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
            f.puts %{[main]\n
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
            f.puts %{[main]\n
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
            f.puts %{[main]\n
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
        assert_nothing_raised do
            config.setdefaults :test, :blocktest => {:default => "yay", :desc => "boo", :hook => proc { |value| testing = value }}
        end
        elem = config.element(:blocktest)

        assert_nothing_raised do
            assert_equal("yay", elem.value)
        end

        assert_nothing_raised do
            config[:blocktest] = "yaytest"
        end

        assert_nothing_raised do
            assert_equal("yaytest", elem.value)
        end
        assert_equal("yaytest", testing)

        assert_nothing_raised do
            config[:blocktest] = "another"
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

        comp = config.to_configuration

        comp.vertices.find_all { |r| r.class.name == :user }.each do |u|
            assert(u.name != "root", "Tried to manage root user")
        end
        comp.vertices.find_all { |r| r.class.name == :group }.each do |u|
            assert(u.name != "root", "Tried to manage root group")
            assert(u.name != "wheel", "Tried to manage wheel group")
        end

#        assert(yay, "Did not find yay component")
#        yay.each do |c|
#            puts @config.ref
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

    # #484
    def test_parsing_unknown_variables
        logstore()
        config = mkconfig()
        config.setdefaults(:mysection, :one => ["yay", "yay"])
        file = tempfile()
        File.open(file, "w") { |f|
            f.puts %{[main]\n
                one = one
                two = yay
            }
        }

        assert_nothing_raised("Unknown parameter threw an exception") do
            config.parse(file)
        end
    end

    def test_multiple_interpolations
        @config.setdefaults(:section,
            :one => ["oneval", "yay"],
            :two => ["twoval", "yay"],
            :three => ["$one/$two", "yay"]
        )

        assert_equal("oneval/twoval", @config[:three],
            "Did not interpolate multiple variables")
    end

    # Make sure we can replace ${style} var names
    def test_curly_replacements
        @config.setdefaults(:section,
            :one => ["oneval", "yay"],
            :two => ["twoval", "yay"],
            :three => ["$one/${two}/${one}/$two", "yay"]
        )

        assert_equal("oneval/twoval/oneval/twoval", @config[:three],
            "Did not interpolate curlied variables")
    end

    # Test to make sure that we can set and get a short name
    def test_celement_short_name
        element = nil
        assert_nothing_raised("Could not create celement") do
            element = CElement.new :short => "n", :desc => "anything", :settings => Puppet::Util::Settings.new
        end
        assert_equal("n", element.short, "Short value is not retained")

        assert_raise(ArgumentError,"Allowed multicharactered short names.") do
            element = CElement.new :short => "no", :desc => "anything", :settings => Puppet::Util::Settings.new
        end
    end

    # Test to make sure that no two celements have the same short name
    def test_celement_short_name_not_duplicated
        config = mkconfig
        assert_nothing_raised("Could not create celement with short name.") do
            config.setdefaults(:main,
                               :one => { :default => "blah", :desc => "anything", :short => "o" })
        end
        assert_nothing_raised("Could not create second celement with short name.") do
            config.setdefaults(:main,
                               :two => { :default => "blah", :desc => "anything", :short => "i" })
        end
        assert_raise(ArgumentError, "Could create second celement with duplicate short name.") do
            config.setdefaults(:main,
                               :three => { :default => "blah", :desc => "anything", :short => "i" })
        end
        # make sure that when the above raises an expection that the config is not included
        assert(!config.include?(:three), "Invalid configuration item was retained")
    end

    # Tell getopt which arguments are valid
    def test_get_getopt_args
        element = CElement.new :name => "foo", :desc => "anything", :settings => Puppet::Util::Settings.new
        assert_equal([["--foo", GetoptLong::REQUIRED_ARGUMENT]], element.getopt_args, "Did not produce appropriate getopt args")
        
        element.short = "n"
        assert_equal([["--foo", "-n", GetoptLong::REQUIRED_ARGUMENT]], element.getopt_args, "Did not produce appropriate getopt args")

        element = CBoolean.new :name => "foo", :desc => "anything", :settings => Puppet::Util::Settings.new
        assert_equal([["--foo", GetoptLong::NO_ARGUMENT], ["--no-foo", GetoptLong::NO_ARGUMENT]],
                     element.getopt_args, "Did not produce appropriate getopt args")

        element.short = "n"
        assert_equal([["--foo", "-n", GetoptLong::NO_ARGUMENT],["--no-foo", GetoptLong::NO_ARGUMENT]],
                      element.getopt_args, "Did not produce appropriate getopt args")
    end
end

