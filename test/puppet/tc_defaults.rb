if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk/"
end

require 'puppet'
require 'test/unit'

# $Id$

class TestPuppetDefaults < Test::Unit::TestCase
    @@dirs = %w{rrddir puppetconf puppetvar logdir statedir certdir bucketdir}
    @@files = %w{logfile checksumfile localcert localkey localpub mastercert masterkey masterpub}
    @@booleans = %w{rrdgraph noop}
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

    def testContained
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
                assert_nothing_raised { raise "%s is in wrong dir: %s" %
                    [param,value] }
            end
        }
    end
end
