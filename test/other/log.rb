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

    def teardown
        super
        Puppet::Log.close
    end

    def getlevels
        levels = nil
        assert_nothing_raised() {
            levels = []
            Puppet::Log.eachlevel { |level| levels << level }
        }
        # Don't test the top levels; too annoying
        return levels.reject { |level| level == :emerg or level == :crit }
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
        fact = nil
        levels = nil
        oldlevel = Puppet[:loglevel]
        Puppet[:loglevel] = :debug
        levels = getlevels
        logfile = tempfile()
        assert_nothing_raised() {
            Puppet::Log.newdestination(logfile)
        }
        msgs = mkmsgs(levels)
        assert(msgs.length == levels.length)
        Puppet::Log.close
        count = 0
        assert_nothing_raised() {
            File.open(logfile) { |of|
                count = of.readlines.length
            }
        }
        assert(count == levels.length)
        Puppet[:loglevel] = oldlevel
    end

    def test_syslog
        levels = nil
        assert_nothing_raised() {
            levels = getlevels.reject { |level|
                level == :emerg || level == :crit
            }
        }
        assert_nothing_raised() {
            Puppet::Log.newdestination("syslog")
        }
        # there's really no way to verify that we got syslog messages...
        msgs = mkmsgs(levels)
        assert(msgs.length == levels.length)
    end

    def test_consolelog
        Puppet[:debug] = true if __FILE__ == $0
        fact = nil
        levels = getlevels
        assert_nothing_raised() {
            Puppet::Log.newdestination(:console)
        }
        msgs = mkmsgs(levels)
        assert(msgs.length == levels.length)
        Puppet::Log.close
    end

    def test_levelmethods
        assert_nothing_raised() {
            Puppet::Log.newdestination("/dev/null")
        }
        getlevels.each { |level|
            assert_nothing_raised() {
                Puppet.send(level,"Testing for %s" % level)
            }
        }
    end

    def test_output
        olddebug = Puppet[:debug]
        Puppet[:debug] = false
        assert(Puppet.err("This is an error").is_a?(Puppet::Log))
        assert(Puppet.debug("This is debugging").nil?)
        Puppet[:debug] = true
        assert(Puppet.err("This is an error").is_a?(Puppet::Log))
        assert(Puppet.debug("This is debugging").is_a?(Puppet::Log))
        Puppet[:debug] = olddebug
    end

    def test_creatingdirs
        dir = tempfile()
        file = File.join(dir, "logfile")
        Puppet[:logdest] = file
        Puppet.info "testing logs"
        assert(FileTest.directory?(dir))
        assert(FileTest.file?(file))
    end

    def test_logtags
        path = tempfile
        File.open(path, "w") { |f| f.puts "yayness" }

        file = Puppet.type(:file).create(
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

        assert(log.tags, "Got no tags")

        assert_equal(log.tags, file.tags, "Tags were not equal")
        assert_equal(log.source, file.path, "Source was not set correctly")
    end

    # Verify that we can pass strings that match printf args
    def test_percentlogs
        Puppet[:logdest] = :syslog

        assert_nothing_raised {
            Puppet::Log.new(
                :level => :info,
                :message => "A message with %s in it"
            )
        }
    end

    # Verify that the error and source are always strings
    def test_argsAreStrings
        msg = nil
        file = Puppet.type(:file).create(
            :path => tempfile(),
            :check => %w{owner group}
        )
        assert_nothing_raised {
            msg = Puppet::Log.new(:level => :info, :message => "This is a message")
        }
        assert_nothing_raised {
            msg.source = file
        }

        assert_instance_of(String, msg.to_s)
        assert_instance_of(String, msg.source)
    end

    # Verify that loglevel behaves as one expects
    def test_loglevel
        path = tempfile()
        file = Puppet.type(:file).create(
            :path => path,
            :create => true
        )

        assert_nothing_raised {
            assert_equal(:notice, file[:loglevel])
        }

        assert_nothing_raised {
            file[:loglevel] = "warning"
        }

        assert_nothing_raised {
            assert_equal(:warning, file[:loglevel])
        }
    end
end
