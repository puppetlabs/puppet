if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parsedfile'
require 'puppettest'
require 'test/unit'

# Test the different features of the main puppet module
class TestPuppetModule < Test::Unit::TestCase
	include TestPuppet
    include SignalObserver
    def mktestclass
        Class.new do
            def initialize(file)
                @file = file
            end

            def started?
                FileTest.exists?(@file)
            end

            def start
                File.open(@file, "w") do |f| f.puts "" end
            end

            def shutdown
                File.unlink(@file)
            end
        end
    end

    # Make sure that services get correctly started and stopped
    def test_servicehandling
        file = tempfile()
        testclass = mktestclass()

        obj = testclass.new(file)

        assert_nothing_raised {
            Puppet.newservice(obj)
        }

        assert_nothing_raised {
            Puppet.start(false)
        }

        # Give it a sec or so
        sleep 0.3

        assert(obj.started?, "Object was not started")

        assert_nothing_raised {
            Puppet.shutdown(false)
        }
        # Give it a sec or so
        sleep 0.3

        assert(!obj.started?, "Object is still running")

    end

    # Make sure timers are being handled correctly
    def test_timerhandling
        timer = nil
        file = tempfile()
        assert_nothing_raised {
            timer = Puppet.newtimer(
                :interval => 0.1,
                :tolerance => 1,
                :start? => true
            ) do
                File.open(file, "w") do |f| f.puts "" end
                Puppet.shutdown(false)
            end
        }

        assert(timer, "Did not get timer back from Puppet")

        assert_nothing_raised {
            timeout(1) do
                Puppet.start()
            end
        }

        assert(FileTest.exists?(file), "timer never got triggered")
    end
end

# $Id$
