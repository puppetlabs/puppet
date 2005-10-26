if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet/log'
require 'puppet'
require 'puppettest'
require 'test/unit'

# $Id$

class TestLog < Test::Unit::TestCase
    include TestPuppet
    @@logfile = File.join(Puppet[:logdir], "puppettest.log")

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
        Puppet::Log.flush
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

    def test_creatingdirs
        curdest = Puppet[:logdest]

        Puppet[:logdest] = "/tmp/logtesting/logfile"
        Puppet.info "testing logs"
        assert(FileTest.directory?("/tmp/logtesting"))
        assert(FileTest.file?("/tmp/logtesting/logfile"))

        system("rm -rf /tmp/logtesting")
        Puppet[:logdest] = curdest
    end

    def test_logtags
        path = tempfile
        File.open(path, "w") { |f| f.puts "yayness" }

        file = Puppet::Type::PFile.create(
            :path => path,
            :check => [:owner, :group, :mode, :checksum]
        )
        file.tags = %w{this is a test}

        log = nil
        assert_nothing_raised {
            log = Puppet::Log.new(
                :level => :info,
                :source => file,
                :message => "A test message"
            )
        }

        # This is really stupid
        assert(log.tags, "Got no tags")
        assert(log.path, "Got no path")

        assert_equal(log.tags, file.tags, "Tags were not equal")
        assert_equal(log.path, file.path, "Paths were not equal")
    end
end
