if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestRelationships < Test::Unit::TestCase
	include TestPuppet
    def newfile
        assert_nothing_raised() {
            return Puppet.type(:file).create(
                :path => tempfile,
                :check => [:mode, :owner, :group]
            )
        }
    end

    def test_simplerel
        file1 = newfile()
        file2 = newfile()
        assert_nothing_raised {
            file1[:require] = [file2.class.name, file2.name]
        }

        deps = []
        assert_nothing_raised {
            file1.eachdependency { |obj|
                deps << obj
            }
        }

        assert_equal(1, deps.length, "Did not get dependency")

        assert_nothing_raised {
            file1.unsubscribe(file2)
        }

        deps = []
        assert_nothing_raised {
            file1.eachdependency { |obj|
                deps << obj
            }
        }

        assert_equal(0, deps.length, "Still have dependency")
    end

    def test_newsub
        file1 = newfile()
        file2 = newfile()

        sub = nil
        assert_nothing_raised("Could not create subscription") {
            sub = Puppet::Event::Subscription.new(
                :source => file1,
                :target => file2,
                :event => :ALL_EVENTS,
                :callback => :refresh
            )
        }

        subs = nil

        assert_nothing_raised {
            subs = Puppet::Event::Subscription.subscribers(file1)
        }
        assert_equal(1, subs.length, "Got incorrect number of subs")
        assert_equal(sub.target, subs[0], "Got incorrect sub")

        deps = nil
        assert_nothing_raised {
            deps = Puppet::Event::Subscription.dependencies(file2)
        }
        assert_equal(1, deps.length, "Got incorrect number of deps")
        assert_equal(sub, deps[0], "Got incorrect dep")
    end

    def test_eventmatch
        file1 = newfile()
        file2 = newfile()

        sub = nil
        assert_nothing_raised("Could not create subscription") {
            sub = Puppet::Event::Subscription.new(
                :source => file1,
                :target => file2,
                :event => :ALL_EVENTS,
                :callback => :refresh
            )
        }

        assert(sub.match?(:anything), "ALL_EVENTS did not match")
        assert(! sub.match?(:NONE), "ALL_EVENTS matched :NONE")

        sub.event = :file_created

        assert(sub.match?(:file_created), "event did not match")
        assert(sub.match?(:ALL_EVENTS), "ALL_EVENTS did not match")
        assert(! sub.match?(:NONE), "ALL_EVENTS matched :NONE")

        sub.event = :NONE

        assert(! sub.match?(:file_created), "Invalid match")
        assert(! sub.match?(:ALL_EVENTS), "ALL_EVENTS matched")
        assert(! sub.match?(:NONE), "matched :NONE")
    end
end

# $Id$
