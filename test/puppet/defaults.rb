if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = ".."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

# $Id$

class TestPuppetDefaults < Test::Unit::TestCase
    include TestPuppet
    @@dirs = %w{rrddir puppetconf puppetvar logdir statedir}
    @@files = %w{logfile checksumfile manifest masterlog}
    @@normals = %w{puppetport masterport server}
    @@booleans = %w{rrdgraph noop}

    def testVersion
        assert( Puppet.version =~ /^[0-9]+(\.[0-9]+)*$/ )
    end

    def testStringOrParam
        [@@dirs,@@files,@@booleans].flatten.each { |param|
            assert_nothing_raised { Puppet[param] }
            assert_nothing_raised { Puppet[param.intern] }
        }
    end

    def test_valuesForEach
        [@@dirs,@@files,@@booleans].flatten.each { |param|
            param = param.intern
            assert_nothing_raised { Puppet[param] }
        }
    end

    def testValuesForEach
        [@@dirs,@@files,@@booleans].flatten.each { |param|
            assert_nothing_raised { Puppet[param] }
        }
    end

    if __FILE__ == $0
        def disabled_testContained
            confdir = Regexp.new(Puppet[:puppetconf])
            vardir = Regexp.new(Puppet[:puppetvar])
            [@@dirs,@@files].flatten.each { |param|
                value = Puppet[param]

                unless value =~ confdir or value =~ vardir
                    assert_nothing_raised { raise "%s is in wrong dir: %s" %
                        [param,value] }
                end
            }
        end
    end

    def testArgumentTypes
        assert_raise(ArgumentError) { Puppet[["string"]] }
        assert_raise(ArgumentError) { Puppet[[:symbol]] }
    end

    def testFailOnBogusArgs
        [0, "ashoweklj", ";", :thisisafakesymbol].each { |param|
            assert_raise(ArgumentError) { Puppet[param] }
        }
    end

    # we don't want user defaults in /, or root defaults in ~
    def testDefaultsInCorrectRoots
        notval = nil
        if Process.uid == 0
            notval = Regexp.new(File.expand_path("~"))
        else
            notval = /^\/var|^\/etc/
        end
        [@@dirs,@@files].flatten.each { |param|
            value = Puppet[param]

            unless value !~ notval
                assert_nothing_raised { raise "%s is incorrectly set to %s" %
                    [param,value] }
            end
        }
    end

    def test_settingdefaults
        testvals = {
            :fakeparam => [:puppetconf, "yaytest"],
            :anotherparam => proc { File.join(Puppet[:puppetvar], "goodtest") },
            :string => "a yay string",
            :boolean => true
        }

        testvals.each { |param, default|
            assert_nothing_raised {
                Puppet.setdefault(param,default)
            }
        }
    end
end
