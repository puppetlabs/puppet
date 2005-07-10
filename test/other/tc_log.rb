if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk/"
end

require 'puppet/log'
require 'puppet'
require 'test/unit'

# $Id$

class TestLog < Test::Unit::TestCase
    @@logfile = "/tmp/puppettest.log"

    def teardown
        system("rm -f %s" % @@logfile)
        Puppet::Log.destination=(:console)
        Puppet[:loglevel] = :notice
    end

    def getlevels
        levels = nil
        assert_nothing_raised() {
            levels = Puppet::Log.levels
        }
        return levels 
    end

    def mkmsgs(levels)
        levels.collect { |level|
            assert_nothing_raised() {
                Puppet::Log.new(
                    :level => level,
                    :source => "Test",
                    :message => "Unit test for %s" % level
                )
            }
        }
    end

    def test_logfile
        Puppet[:debug] = true if __FILE__ == $0
        fact = nil
        levels = nil
        levels = getlevels
        assert_nothing_raised() {
            Puppet::Log.destination=(@@logfile)
        }
        msgs = mkmsgs(levels)
        assert(msgs.length == levels.length)
        Puppet::Log.close
        count = 0
        assert_nothing_raised() {
            File.open(@@logfile) { |of|
                count = of.readlines.length
            }
        }
        assert(count == levels.length)
    end

    def test_syslog
        levels = nil
        assert_nothing_raised() {
            levels = getlevels.reject { |level|
                level == :emerg || level == :crit
            }
        }
        assert_nothing_raised() {
            Puppet::Log.destination=("syslog")
        }
        # there's really no way to verify that we got syslog messages...
        msgs = mkmsgs(levels)
        assert(msgs.length == levels.length)
    end

    def test_consolelog
        Puppet[:debug] = true if __FILE__ == $0
        fact = nil
        levels = nil
        assert_nothing_raised() {
            levels = Puppet::Log.levels
        }
        assert_nothing_raised() {
            Puppet::Log.destination=(:console)
        }
        msgs = mkmsgs(levels)
        assert(msgs.length == levels.length)
        Puppet::Log.close
    end

    def test_levelmethods
        assert_nothing_raised() {
            Puppet::Log.destination=("/dev/null")
        }
        getlevels.each { |level|
            assert_nothing_raised() {
                Puppet.send(level,"Testing for %s" % level)
            }
        }
    end

    def test_output
        Puppet[:debug] = false
        assert(Puppet.err("This is an error").is_a?(Puppet::Log))
        assert(Puppet.debug("This is debugging").nil?)
        Puppet[:debug] = true
        assert(Puppet.err("This is an error").is_a?(Puppet::Log))
        assert(Puppet.debug("This is debugging").is_a?(Puppet::Log))
    end
end
