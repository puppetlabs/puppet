# Test cron job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppettest'
require 'puppet'
require 'puppet/type/cron'
require 'test/unit'
require 'facter'

class TestExec < Test::Unit::TestCase
	include TestPuppet
    def setup
        super
        # retrieve the user name
        id = %x{id}.chomp
        if id =~ /uid=\d+\(([^\)]+)\)/
            @me = $1
        else
            puts id
        end
        unless defined? @me
            raise "Could not retrieve user name; 'id' did not work"
        end
        # god i'm lazy
        @crontype = Puppet::Type::Cron
    end

    # Back up the user's existing cron tab if they have one.
    def cronback
        tab = nil
        assert_nothing_raised {
            tab = Puppet::Type::Cron.crontype.read(@me)
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
                @crontype.crontype.write(@me, @currenttab)
            else
                @crontype.crontype.remove(@me)
            end
        }
    end

    # Create a cron job with all fields filled in.
    def mkcron(name)
        cron = nil
        assert_nothing_raised {
            cron = @crontype.create(
                :command => "date > %s/crontest%s" % [tmpdir(), name],
                :name => name,
                :user => @me,
                :minute => rand(59),
                :month => "1",
                :monthday => "1",
                :hour => "1"
            )
        }

        return cron
    end

    # Run the cron through its paces -- install it then remove it.
    def cyclecron(cron)
        name = cron.name
        comp = newcomp(name, cron)

        trans = assert_events(comp, [:cron_created], name)
        cron.retrieve
        assert(cron.insync?)
        trans = assert_events(comp, [], name)
        cron[:command] = :notfound
        trans = assert_events(comp, [:cron_deleted], name)
        # the cron should no longer exist, not even in the comp
        trans = assert_events(comp, [], name)

        assert(!comp.include?(cron),
            "Cron is still a member of comp, after being deleted")
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
                :command => "date",
                :user => @me
            )
        }
        str = nil
        # generate the text
        assert_nothing_raised {
            str = cron.to_cron
        }
        assert_equal(str, "# Puppet Name: #{name}\n* * * * * date",
            "Cron did not generate correctly")
    end
    
    # Test that comments are correctly retained
    def test_retain_comments
        str = "# this is a comment\n#and another comment\n"
        user = "fakeuser"
        assert_nothing_raised {
            @crontype.parse(user, str)
        }

        assert_nothing_raised {
            newstr = @crontype.tab(user)
            assert_equal(str, newstr, "Cron comments were changed or lost")
        }
    end

    # Test that a specified cron job will be matched against an existing job
    # with no name, as long as all fields match
    def test_matchcron
        str = "0,30 * * * * date\n"

        assert_nothing_raised {
            @crontype.parse(@me, str)
        }

        assert_nothing_raised {
            cron = @crontype.create(
                :name => "yaycron",
                :minute => [0, 30],
                :command => "date",
                :user => @me
            )
        }

        modstr = "# Puppet Name: yaycron\n%s" % str

        assert_nothing_raised {
            newstr = @crontype.tab(@me)
            assert_equal(modstr, newstr, "Cron was not correctly matched")
        }
    end

    # Test adding a cron when there is currently no file.
    def test_mkcronwithnotab
        cronback
        Puppet::Type::Cron.crontype.remove(@me)

        cron = mkcron("testwithnotab")
        cyclecron(cron)
        cronrestore
    end

    def test_mkcronwithtab
        cronback
        Puppet::Type::Cron.crontype.remove(@me)
        Puppet::Type::Cron.crontype.write(@me,
"1 1 1 1 * date > %s/crontesting\n" % testdir()
        )

        cron = mkcron("testwithtab")
        cyclecron(cron)
        cronrestore
    end

    def test_makeandretrievecron
        cronback
        Puppet::Type::Cron.crontype.remove(@me)

        name = "storeandretrieve"
        cron = mkcron(name)
        comp = newcomp(name, cron)
        trans = assert_events(comp, [:cron_created], name)
        
        cron = nil

        Puppet::Type::Cron.clear
        Puppet::Type::Cron.retrieve(@me)

        assert(cron = Puppet::Type::Cron[name], "Could not retrieve named cron")
        assert_instance_of(Puppet::Type::Cron, cron)
        cronrestore
    end

    # Do input validation testing on all of the parameters.
    def test_arguments
        values = {
            :monthday => {
                :valid => [ 1, 13, "1,30" ],
                :invalid => [ -1, 0, 32 ]
            },
            :weekday => {
                :valid => [ 0, 3, 6, "1,2", "tue", "wed",
                    "Wed", "MOnday", "SaTurday" ],
                :invalid => [ -1, 7, "1, 3", "tues", "teusday", "thurs" ]
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
                :invalid => [ 0, 13, "marc", "sept" ]
            }
        }

        cron = mkcron("valtesting")
        values.each { |param, hash|
            hash.each { |type, values|
                values.each { |value|
                    case type
                    when :valid:
                        assert_nothing_raised {
                            cron[param] = value
                        }

                        if value.is_a?(Integer)
                            assert_equal([value], cron[param],
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
end

# $Id$
