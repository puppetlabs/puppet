if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'puppettest'
require 'test/unit'

# $Id$

class TestEvents < Test::Unit::TestCase
	include TestPuppet
    def teardown
        super
        Puppet::Event::Subscription.clear
    end

    def test_simplesubscribe
        name = tempfile()
        file = Puppet::Type::PFile.create(
            :name => name,
            :create => true
        )
        exec = Puppet::Type::Exec.create(
            :name => "echo true",
            :path => "/usr/bin:/bin",
            :refreshonly => true,
            :subscribe => [[file.class.name, file.name]] 
        )

        comp = newcomp("eventtesting", file, exec)

        trans = assert_events(comp, [:file_created], "events")

        assert_equal(1, trans.triggered?(exec, :refresh))
    end

    def test_simplerequire
        name = tempfile()
        file = Puppet::Type::PFile.create(
            :name => name,
            :create => true
        )
        exec = Puppet::Type::Exec.create(
            :name => "echo true",
            :path => "/usr/bin:/bin",
            :refreshonly => true,
            :require => [[file.class.name, file.name]] 
        )


        comp = Puppet::Type::Component.create(
            :name => "eventtesting"
        )
        comp.push exec
        trans = comp.evaluate
        events = nil
        assert_nothing_raised {
            events = trans.evaluate
        }

        assert_equal(1, events.length)

        assert_equal(0, trans.triggered?(exec, :refresh))
    end

    def test_ladderrequire
        comps = {}
        objects = {}
        fname = tempfile()
        [:a, :b].each { |l|
            case l
            when :a
                name = tempfile() + l.to_s
                objects[l] = Puppet::Type::PFile.create(
                    :name => name,
                    :create => true
                )
                @@tmpfiles << name
            when :b
                objects[l] = Puppet::Type::Exec.create(
                    :name => "touch %s" % fname,
                    :path => "/usr/bin:/bin",
                    :refreshonly => true
                )
                @@tmpfiles << fname
            end


            comps[l] = Puppet::Type::Component.create(
                :name => "eventtesting%s" % l
            )

            comps[l].push objects[l]
        }

        comps[:b][:subscribe] = [[comps[:a].class.name, comps[:a].name]]

        trans = comps[:a].evaluate
        events = nil
        assert_nothing_raised {
            events = trans.evaluate
        }

        assert(FileTest.exists?(fname))
        #assert_equal(events.length, trans.triggered?(objects[:b], :refresh))
    end
end
