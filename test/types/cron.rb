#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

# Test cron job creation, modification, and destruction

require 'puppettest'
require 'puppet'
require 'facter'

class TestCron < Test::Unit::TestCase
	include PuppetTest
    def setup
        super

        setme()

        # god i'm lazy
        @crontype = Puppet.type(:cron)
        @oldfiletype = @crontype.filetype
        @fakefiletype = Puppet::FileType.filetype(:ram)
        @crontype.filetype = @fakefiletype
    end

    def teardown
        @crontype.filetype = @oldfiletype
        Puppet::FileType.filetype(:ram).clear
        super
    end

    # Back up the user's existing cron tab if they have one.
    def cronback
        tab = nil
        assert_nothing_raised {
            tab = Puppet.type(:cron).filetype.read(@me)
        }

        if $? == 0
            @currenttab = tab
        else
            @currenttab = nil
        end
    end

    # Restore the cron tab to its original form.
    def cronrestore
        assert_nothing_raised {
            if @currenttab
                @crontype.filetype.new(@me).write(@currenttab)
            else
                @crontype.filetype.new(@me).remove
            end
        }
    end

    # Create a cron job with all fields filled in.
    def mkcron(name, addargs = true)
        cron = nil
        command = "date > %s/crontest%s" % [tmpdir(), name]
        args = nil
        if addargs
            args = {
                :command => command,
                :name => name,
                :user => @me,
                :minute => rand(59),
                :month => "1",
                :monthday => "1",
                :hour => "1"
            }
        else
            args = {:command => command, :name => name}
        end
        assert_nothing_raised {
            cron = @crontype.create(args)
        }

        return cron
    end

    # Run the cron through its paces -- install it then remove it.
    def cyclecron(cron)
        obj = Puppet::Type::Cron.cronobj(@me)

        text = obj.read
        name = cron.name
        comp = newcomp(name, cron)

        assert_events([:cron_created], comp)
        cron.retrieve

        assert(cron.insync?, "Cron is not in sync")

        assert_events([], comp)

        curtext = obj.read
        text.split("\n").each do |line|
            assert(curtext.include?(line), "Missing '%s'" % line)
        end
        obj = Puppet::Type::Cron.cronobj(@me)

        cron[:ensure] = :absent

        assert_events([:cron_removed], comp)

        cron.retrieve

        assert(cron.insync?, "Cron is not in sync")
        assert_events([], comp)
    end

    # A simple test to see if we can load the cron from disk.
    def test_load
        assert_nothing_raised {
            @crontype.retrieve(@me)
        }
    end

    # Test that a cron job turns out as expected, by creating one and generating
    # it directly
    def test_simple_to_cron
        cron = nil
        # make the cron
        name = "yaytest"
        assert_nothing_raised {
            cron = @crontype.create(
                :name => name,
                :command => "date > /dev/null",
                :user => @me
            )
        }
        str = nil
        # generate the text
        assert_nothing_raised {
            str = cron.to_record
        }

        assert_equal(str, "# Puppet Name: #{name}\n* * * * * date > /dev/null",
            "Cron did not generate correctly")
    end

    def test_simpleparsing
        @fakefiletype = Puppet::FileType.filetype(:ram)
        @crontype.filetype = @fakefiletype

        @crontype.retrieve(@me)
        obj = Puppet::Type::Cron.cronobj(@me)

        text = "5 1,2 * 1 0 /bin/echo funtest"

        assert_nothing_raised {
            @crontype.parse(@me, text)
        }

        @crontype.each do |obj|
            assert_equal(["5"], obj.is(:minute), "Minute was not parsed correctly")
            assert_equal(["1", "2"], obj.is(:hour), "Hour was not parsed correctly")
            assert_equal([:absent], obj.is(:monthday), "Monthday was not parsed correctly")
            assert_equal(["1"], obj.is(:month), "Month was not parsed correctly")
            assert_equal(["0"], obj.is(:weekday), "Weekday was not parsed correctly")
            assert_equal(["/bin/echo funtest"], obj.is(:command), "Command was not parsed correctly")
        end
    end

    # Test that changing any field results in the cron tab being rewritten.
    # it directly
    def test_any_field_changes
        cron = nil
        # make the cron
        name = "yaytest"
        assert_nothing_raised {
            cron = @crontype.create(
                :name => name,
                :command => "date > /dev/null",
                :month => "May",
                :user => @me
            )
        }
        assert(cron, "Cron did not get created")
        comp = newcomp(cron)
        assert_events([:cron_created], comp)

        assert_nothing_raised {
            cron[:month] = "June"
        }

        cron.retrieve

        assert_events([:cron_changed], comp)
    end

    # Test that a cron job with spaces at the end doesn't get rewritten
    def test_trailingspaces
        cron = nil
        # make the cron
        name = "yaytest"
        assert_nothing_raised {
            cron = @crontype.create(
                :name => name,
                :command => "date > /dev/null ",
                :month => "May",
                :user => @me
            )
        }
        comp = newcomp(cron)

        assert_events([:cron_created], comp, "did not create cron job")
        cron.retrieve
        assert_events([], comp, "cron job got rewritten")
    end
    
    # Test that comments are correctly retained
    def test_retain_comments
        str = "# this is a comment\n#and another comment\n"
        user = "fakeuser"
        @crontype.retrieve(@me)
        assert_nothing_raised {
            @crontype.parse(@me, str)
        }

        assert_nothing_raised {
            newstr = @crontype.tab(@me)
            assert(newstr.include?(str), "Comments were lost")
        }
    end

    # Test that a specified cron job will be matched against an existing job
    # with no name, as long as all fields match
    def test_matchcron
        str = "0,30 * * * * date\n"

        assert_nothing_raised {
            cron = @crontype.create(
                :name => "yaycron",
                :minute => [0, 30],
                :command => "date",
                :user => @me
            )
        }

        assert_nothing_raised {
            @crontype.parse(@me, str)
        }

        count = @crontype.inject(0) do |c, obj|
            c + 1
        end

        assert_equal(1, count, "Did not match cron job")

        modstr = "# Puppet Name: yaycron\n%s" % str

        assert_nothing_raised {
            newstr = @crontype.tab(@me)
            assert(newstr.include?(modstr),
                "Cron was not correctly matched")
        }
    end

    # Test adding a cron when there is currently no file.
    def test_mkcronwithnotab
        tab = @fakefiletype.new(@me)
        tab.remove

        @crontype.retrieve(@me)
        cron = mkcron("testwithnotab")
        cyclecron(cron)
    end

    def test_mkcronwithtab
        @crontype.retrieve(@me)
        obj = Puppet::Type::Cron.cronobj(@me)
        obj.write(
"1 1 1 1 * date > %s/crontesting\n" % tstdir()
        )

        cron = mkcron("testwithtab")
        cyclecron(cron)
    end

    def test_makeandretrievecron
        tab = @fakefiletype.new(@me)
        tab.remove

        %w{storeandretrieve a-name another-name more_naming SomeName}.each do |name|
            cron = mkcron(name)
            comp = newcomp(name, cron)
            trans = assert_events([:cron_created], comp, name)
            
            cron = nil

            Puppet.type(:cron).retrieve(@me)

            assert(cron = Puppet.type(:cron)[name], "Could not retrieve named cron")
            assert_instance_of(Puppet.type(:cron), cron)
        end
    end

    # Do input validation testing on all of the parameters.
    def test_arguments
        values = {
            :monthday => {
                :valid => [ 1, 13, "1" ],
                :invalid => [ -1, 0, 32 ]
            },
            :weekday => {
                :valid => [ 0, 3, 6, "1", "tue", "wed",
                    "Wed", "MOnday", "SaTurday" ],
                :invalid => [ -1, 7, "13", "tues", "teusday", "thurs" ]
            },
            :hour => {
                :valid => [ 0, 21, 23 ],
                :invalid => [ -1, 24 ]
            },
            :minute => {
                :valid => [ 0, 34, 59 ],
                :invalid => [ -1, 60 ]
            },
            :month => {
                :valid => [ 1, 11, 12, "mar", "March", "apr", "October", "DeCeMbEr" ],
                :invalid => [ -1, 0, 13, "marc", "sept" ]
            }
        }

        cron = mkcron("valtesting")
        values.each { |param, hash|
            # We have to test the valid ones first, because otherwise the
            # state will fail to create at all.
            [:valid, :invalid].each { |type|
                hash[type].each { |value|
                    case type
                    when :valid:
                        assert_nothing_raised {
                            cron[param] = value
                        }

                        if value.is_a?(Integer)
                            assert_equal(value.to_s, cron.should(param),
                                "Cron value was not set correctly")
                        end
                    when :invalid:
                        assert_raise(Puppet::Error, "%s is incorrectly a valid %s" %
                            [value, param]) {
                            cron[param] = value
                        }
                    end

                    if value.is_a?(Integer)
                        value = value.to_s
                        redo
                    end
                }
            }
        }
    end

    # Test that we can read and write cron tabs
    def test_crontab
        Puppet.type(:cron).filetype = Puppet.type(:cron).defaulttype
        type = nil
        unless type = Puppet.type(:cron).filetype
            $stderr.puts "No crontab type; skipping test"
        end

        obj = nil
        assert_nothing_raised {
            obj = type.new(Puppet::SUIDManager.uid)
        }

        txt = nil
        assert_nothing_raised {
            txt = obj.read
        }

        assert_nothing_raised {
            obj.write(txt)
        }
    end

    # Verify that comma-separated numbers are not resulting in rewrites
    def test_norewrite
        cron = nil
        assert_nothing_raised {
            cron = Puppet.type(:cron).create(
                :command => "/bin/date > /dev/null",
                :minute => [0, 30],
                :name => "crontest"
            )
        }

        assert_events([:cron_created], cron)
        cron.retrieve
        assert_events([], cron)
    end

    def test_fieldremoval
        cron = nil
        assert_nothing_raised {
            cron = Puppet.type(:cron).create(
                :command => "/bin/date > /dev/null",
                :minute => [0, 30],
                :name => "crontest"
            )
        }

        assert_events([:cron_created], cron)

        cron[:minute] = :absent
        assert_events([:cron_changed], cron)
        assert_nothing_raised {
            cron.retrieve
        }
        assert_equal(:absent, cron.is(:minute))
    end

    def test_listing
        @crontype.filetype = @oldfiletype

        crons = []
        assert_nothing_raised {
            Puppet::Type.type(:cron).list.each do |cron|
                crons << cron
            end
        }

        crons.each do |cron|
            assert(cron, "Did not receive a real cron object")
            assert_instance_of(String, cron[:user],
                "Cron user is not a string")
        end
    end

    def verify_failonnouser
        assert_raise(Puppet::Error) do
            @crontype.retrieve("nosuchuser")
        end
    end

    def test_names
        cron = mkcron("nametest")

        ["bad name", "bad.name"].each do |name|
            assert_raise(ArgumentError) do
                cron[:name] = name
            end
        end

        ["good-name", "good-name", "AGoodName"].each do |name|
            assert_nothing_raised do
                cron[:name] = name
            end
        end
    end

    # Make sure we don't puke on env settings
    def test_envsettings
        cron = mkcron("envtst")

        assert_apply(cron)

        obj = Puppet::Type::Cron.cronobj(@me)

        assert(obj)

        text = obj.read

        text = "SHELL = /path/to/some/thing\n" + text

        obj.write(text)

        assert_nothing_raised {
            cron.retrieve
        }

        cron[:command] = "/some/other/command"

        assert_apply(cron)

        assert(obj.read =~ /SHELL/, "lost env setting")

        env1 = "TEST = /bin/true"
        env2 = "YAY = fooness"
        assert_nothing_raised {
            cron[:environment] = [env1, env2]
        }

        assert_apply(cron)

        cron.retrieve

        vals = cron.is(:environment)
        assert(vals, "Did not get environment settings")
        assert(vals != :absent, "Env is incorrectly absent")
        assert_instance_of(Array, vals)

        assert(vals.include?(env1), "Missing first env setting")
        assert(vals.include?(env2), "Missing second env setting")

        # Now do it again and make sure there are no changes
        assert_events([], cron)

    end

    def test_divisionnumbers
        cron = mkcron("divtest")
        cron[:minute] = "*/5"

        assert_apply(cron)

        cron.retrieve

        assert_equal(["*/5"], cron.is(:minute))
    end

    def test_ranges
        cron = mkcron("rangetest")
        cron[:minute] = "2-4"

        assert_apply(cron)

        cron.retrieve

        assert_equal(["2-4"], cron.is(:minute))
    end

    def test_data
        @fakefiletype = Puppet::FileType.filetype(:ram)
        @crontype.filetype = @fakefiletype

        @crontype.retrieve(@me)
        obj = Puppet::Type::Cron.cronobj(@me)

        fakedata("data/types/cron").each do |file|
            names = []
            text = File.read(file)
            obj.write(File.read(file))

            @crontype.retrieve(@me)

            @crontype.each do |cron|
                names << cron.name
            end

            name = File.basename(file)
            cron = mkcron("filetest-#{name}")

            assert_apply(cron)

            @crontype.retrieve(@me)

            names.each do |name|
                assert(@crontype[name], "Could not retrieve %s" % name)
            end

            tablines = @crontype.tab(@me).split("\n")

            text.split("\n").each do |line|
                assert(tablines.include?(line),
                    "Did not get %s back out" % line.inspect)
            end
        end
    end

    def test_value
        cron = mkcron("valuetesting", false)

        # First, test the normal states
        [:minute, :hour, :month].each do |param|
            cron.newstate(param)
            state = cron.state(param)

            assert(state, "Did not get %s state" % param)

            assert_nothing_raised {
                state.is = :absent
            }

            # Make sure our minute default is 0, not *
            val = if param == :minute
                "*" # the "0" thing is disabled for now
            else
                "*"
            end
            assert_equal(val, cron.value(param))

            # Make sure we correctly get the "is" value if that's all there is
            cron.is = [param, "1"]
            assert_equal("1", cron.value(param))

            # Make sure arrays work, too
            cron.is = [param, ["1"]]
            assert_equal("1", cron.value(param))

            # Make sure values get comma-joined
            cron.is = [param, ["2", "3"]]
            assert_equal("2,3", cron.value(param))

            # Make sure "should" values work, too
            cron[param] = "4"
            assert_equal("4", cron.value(param))

            cron[param] = ["4"]
            assert_equal("4", cron.value(param))

            cron[param] = ["4", "5"]
            assert_equal("4,5", cron.value(param))

            cron.is = [param, :absent]
            assert_equal("4,5", cron.value(param))
        end

        # Now make sure that :command works correctly
        cron.delete(:command)
        cron.newstate(:command)
        state = cron.state(:command)

        assert_nothing_raised {
            state.is = :absent
        }

        assert(state, "Did not get command state")
        assert_raise(Puppet::DevError) do
            cron.value(:command)
        end

        param = :command
        # Make sure we correctly get the "is" value if that's all there is
        cron.is = [param, "1"]
        assert_equal("1", cron.value(param))

        # Make sure arrays work, too
        cron.is = [param, ["1"]]
        assert_equal("1", cron.value(param))

        # Make sure values are not comma-joined
        cron.is = [param, ["2", "3"]]
        assert_equal("2", cron.value(param))

        # Make sure "should" values work, too
        cron[param] = "4"
        assert_equal("4", cron.value(param))

        cron[param] = ["4"]
        assert_equal("4", cron.value(param))

        cron[param] = ["4", "5"]
        assert_equal("4", cron.value(param))

        cron.is = [param, :absent]
        assert_equal("4", cron.value(param))
    end

    # Make sure we can successfully list all cron jobs on all users
    def test_cron_listing
        crons = []
        %w{fake1 fake2 fake3 fake4 fake5}.each do |user|
            crons << @crontype.create(
                :name => "#{user}-1",
                :command => "/usr/bin/#{user}",
                :minute => "0",
                :user => user,
                :hour => user.sub("fake",'')
            )

            crons << @crontype.create(
                :name => "#{user}-2",
                :command => "/usr/sbin/#{user}",
                :minute => "0",
                :user => user,
                :weekday => user.sub("fake",'')
            )

            assert_apply(*crons)
        end

        list = @crontype.list.collect { |c| c.name }

        crons.each do |cron|
            assert(list.include?(cron.name), "Did not match cron %s" % name)
        end
    end

    # Make sure we can create a cron in an empty tab
    def test_mkcron_if_empty
        @crontype.filetype = @oldfiletype

        @crontype.retrieve(@me)

        # Backup our tab
        text = @crontype.tabobj(@me).read

        cleanup do
            if text == ""
                @crontype.tabobj(@me).remove
            else
                @crontype.tabobj(@me).write(text)
            end
        end

        # Now get rid of it
        @crontype.tabobj(@me).remove
        @crontype.clear

        cron = mkcron("emptycron")

        assert_apply(cron)

        # Clear the type, but don't clear the filetype
        @crontype.clear

        # Get the stuff again
        @crontype.retrieve(@me)

        assert(@crontype["emptycron"],
            "Did not retrieve cron")
    end

    def test_multiple_users
        crons = []
        users = ["root", nonrootuser.name]
        users.each do |user|
            crons << Puppet::Type.type(:cron).create(
                :name => "testcron-#{user}",
                :user => user,
                :command => "/bin/echo",
                :minute => [0,30]
            )
        end

        assert_apply(*crons)

        users.each do |user|
            users.each do |other|
                next if user == other
                assert(Puppet::Type.type(:cron).tabobj(other).read !~ /testcron-#{user}/,
                       "%s's cron job is in %s's tab" %
                       [user, other])
            end
        end
    end
end

# $Id$
