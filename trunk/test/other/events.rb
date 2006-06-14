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

    # Verify that one component can subscribe to another component and the "right"
    # thing happens
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

        fcomp = newcomp(file)
        ecomp = newcomp(exec)
        comp = newcomp("laddercomp", fcomp, ecomp)

        ecomp[:subscribe] = [[fcomp.class.name, fcomp.name]]

        comp.finalize

        trans = comp.evaluate
        events = nil
        assert_nothing_raised {
            events = trans.evaluate
        }

        assert(FileTest.exists?(fname), "#{fname} does not exist")
        #assert_equal(events.length, trans.triggered?(objects[:b], :refresh))
    end

    def test_multiplerefreshes
        files = []

        4.times { |i|
            files << Puppet.type(:file).create(
                :name => tempfile(),
                :ensure => "file"
            )
        }

        fname = tempfile()
        exec = Puppet.type(:exec).create(
            :name => "touch %s" % fname,
            :path => "/usr/bin:/bin",
            :refreshonly => true
        )

        exec[:subscribe] = files.collect { |f|
            ["file", f.name]
        }

        comp = newcomp(exec, *files)

        assert_apply(comp)
        assert(FileTest.exists?(fname), "Exec file did not get created")
    end

    def test_refreshordering
        file = tempfile()

        exec1 = Puppet.type(:exec).create(
            :name => "echo one >> %s" % file,
            :path => "/usr/bin:/bin"
        )

        exec2 = Puppet.type(:exec).create(
            :name => "echo two >> %s" % file,
            :path => "/usr/bin:/bin",
            :refreshonly => true,
            :subscribe => ["exec", exec1.name]
        )

        exec3 = Puppet.type(:exec).create(
            :name => "echo three >> %s" % file,
            :path => "/usr/bin:/bin"
        )

        comp = newcomp(exec1,exec2,exec3)

        assert_apply(comp)

        assert(FileTest.exists?(file), "File does not exist")

        assert_equal("one\ntwo\nthree\n", File.read(file))
    end
end
