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

# $Id$

class TestExec < TestPuppet
    def setup
        id = %x{id}.chomp
        if id =~ /uid=\d+\(([^\)]+)\)/
            @me = $1
        else
            puts id
        end
        unless defined? @me
            raise "Could not retrieve user name; 'id' did not work"
        end
        tab = Puppet::Type::Cron.crontype.read(@me)

        if $? == 0
            @currenttab = tab
        else
            @currenttab = nil
        end

        super
    end

    def teardown
        if @currenttab
            Puppet::Type::Cron.crontype.write(@me, @currenttab)
        else
            Puppet::Type::Cron.crontype.remove(@me)
        end
        super
    end

    def test_load
        assert_nothing_raised {
            Puppet::Type::Cron.retrieve(@me)
        }
    end

    def mkcron(name)
        cron = nil
        assert_nothing_raised {
            cron = Puppet::Type::Cron.create(
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

    def cyclecron(cron)
        name = cron.name
        comp = newcomp(name, cron)

        trans = assert_events(comp, [:cron_created], name)
        cron.retrieve
        assert(cron.insync?)
        trans = assert_events(comp, [], name)
        cron[:command] = :notfound
        trans = assert_events(comp, [:cron_deleted], name)
    end

    def test_mkcronwithnotab
        Puppet::Type::Cron.crontype.remove(@me)

        cron = mkcron("crontest")
        cyclecron(cron)
    end

    def test_mkcronwithtab
        Puppet::Type::Cron.crontype.remove(@me)
        Puppet::Type::Cron.crontype.write(@me,
"1 1 1 1 * date > %s/crontesting\n" % testdir()
        )

        cron = mkcron("crontest")
        cyclecron(cron)
    end

    def test_makeandretrievecron
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
    end

    def test_arguments
        values = {
            :monthday => {
                :valid => [ 1, 13, ],
                :invalid => [ -1, 0, 32 ]
            },
            :weekday => {
                :valid => [ 0, 3, 6, "tue", "wed", "Wed", "MOnday", "SaTurday" ],
                :invalid => [ -1, 7, "tues", "teusday", "thurs" ]
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
                            assert_equal(value, cron[param],
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
