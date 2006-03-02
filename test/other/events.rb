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
        file = Puppet.type(:file).create(
            :name => name,
            :ensure => "file"
        )
        exec = Puppet.type(:exec).create(
            :name => "echo true",
            :path => "/usr/bin:/bin",
            :refreshonly => true,
            :subscribe => [[file.class.name, file.name]] 
        )

        comp = newcomp("eventtesting", file, exec)

        trans = assert_events([:file_created], comp)

        assert_equal(1, trans.triggered?(exec, :refresh))
    end

    def test_simplerequire
        name = tempfile()
        file = Puppet.type(:file).create(
            :name => name,
            :ensure => "file"
        )
        exec = Puppet.type(:exec).create(
            :name => "echo true",
            :path => "/usr/bin:/bin",
            :refreshonly => true,
            :require => [[file.class.name, file.name]] 
        )


        comp = Puppet.type(:component).create(
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
        file = Puppet.type(:file).create(
            :name => tempfile(),
            :ensure => "file"
        )

        exec = Puppet.type(:exec).create(
            :name => "touch %s" % fname,
            :path => "/usr/bin:/bin",
            :refreshonly => true
        )

        comps[:f] = newcomp(file)
        comps[:e] = newcomp(exec)

        comps[:e][:subscribe] = [[comps[:f].class.name, comps[:f].name]]
        comps.each { |l, c|
            c.finalize
        }

        trans = comps[:f].evaluate
        events = nil
        assert_nothing_raised {
            events = trans.evaluate
        }

        assert(FileTest.exists?(fname))
        #assert_equal(events.length, trans.triggered?(objects[:b], :refresh))
    end
end
