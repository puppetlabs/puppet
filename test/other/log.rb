require 'puppet'
require 'puppet/log'
require 'puppettest'

# $Id$

class TestLog < Test::Unit::TestCase
    include PuppetTest

    def setup
        super
        @oldloglevel = Puppet::Log.level
        Puppet::Log.close
    end

    def teardown
        super
        Puppet::Log.close
        Puppet::Log.level = @oldloglevel
        Puppet::Log.newdestination(:console)
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
            next if level == :alert
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
        Puppet::Log.level = :debug
        levels = getlevels
        logfile = tempfile()
        fact = nil
        assert_nothing_raised() {
            Puppet::Log.newdestination(logfile)
        }
        msgs = mkmsgs(levels)
        assert(msgs.length == levels.length)
        Puppet::Log.close
        count = 0

        assert(FileTest.exists?(logfile), "Did not create logfile")

        assert_nothing_raised() {
            File.open(logfile) { |of|
                count = of.readlines.length
            }
        }
        assert(count == levels.length - 1) # skip alert
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
        Puppet::Log.level = :notice
        assert(Puppet.err("This is an error").is_a?(Puppet::Log))
        assert(Puppet.debug("This is debugging").nil?)
        Puppet::Log.level = :debug
        assert(Puppet.err("This is an error").is_a?(Puppet::Log))
        assert(Puppet.debug("This is debugging").is_a?(Puppet::Log))
    end

    def test_creatingdirs
        dir = tempfile()
        file = File.join(dir, "logfile")
        Puppet::Log.newdestination file
        Puppet.info "testing logs"
        assert(FileTest.directory?(dir))
        assert(FileTest.file?(file))
    end

    def test_logtags
        path = tempfile
        File.open(path, "w") { |f| f.puts "yayness" }

        file = Puppet.type(:file).create(
            :path => path,
            :check => [:owner, :group, :mode, :checksum],
            :ensure => :file
        )
        file.tags = %w{this is a test}

        state = file.state(:ensure)
        assert(state, "Did not get state")
        log = nil
        assert_nothing_raised {
            log = Puppet::Log.new(
                :level => :info,
                :source => state,
                :message => "A test message"
            )
        }

        # Now yaml and de-yaml it, and test again
        yamllog = YAML.load(YAML.dump(log))

        {:log => log, :yaml => yamllog}.each do |type, msg|
            assert(msg.tags, "Got no tags")

            msg.tags.each do |tag|
                assert(msg.tagged?(tag), "Was not tagged with %s" % tag)
            end

            assert_equal(msg.tags, state.tags, "Tags were not equal")
            assert_equal(msg.source, state.path, "Source was not set correctly")
        end

    end

    # Verify that we can pass strings that match printf args
    def test_percentlogs
        Puppet::Log.newdestination :syslog

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
            :ensure => "file"
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

    def test_destination_matching
        dest = nil
        assert_nothing_raised {
            dest = Puppet::Log.newdesttype("Destine") do
                def handle(msg)
                    puts msg
                end
            end
        }

        [:destine, "Destine", "destine"].each do |name|
            assert(dest.match?(name), "Did not match %s" % name.inspect)
        end

        assert_nothing_raised {
            dest.match(:yayness)
        }
        assert(dest.match("Yayness"), "Did not match yayness")
        Puppet::Log.close(dest)
    end
end
