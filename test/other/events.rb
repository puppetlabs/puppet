#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppettest'


class TestEvents < Test::Unit::TestCase
	include PuppetTest

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

        comp = mk_configuration("eventtesting", file, exec)

        trans = assert_events([:file_created, :triggered], comp)

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


        config = mk_configuration
        config.add_resource file
        config.add_resource exec
        trans = config.apply

        assert_equal(1, trans.events.length)

        assert_equal(0, trans.triggered?(exec, :refresh))
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

        comp = mk_configuration(exec, *files)

        assert_apply(comp)
        assert(FileTest.exists?(fname), "Exec file did not get created")
    end

    # Make sure refreshing happens mid-transaction, rather than at the end.
    def test_refreshordering
        file = tempfile()

        exec1 = Puppet.type(:exec).create(
            :title => "one",
            :name => "echo one >> %s" % file,
            :path => "/usr/bin:/bin"
        )

        exec2 = Puppet.type(:exec).create(
            :title => "two",
            :name => "echo two >> %s" % file,
            :path => "/usr/bin:/bin",
            :refreshonly => true,
            :subscribe => exec1
        )

        exec3 = Puppet.type(:exec).create(
            :title => "three",
            :name => "echo three >> %s" % file,
            :path => "/usr/bin:/bin",
            :require => exec2
        )
        execs = [exec1, exec2, exec3]

        config = mk_configuration(exec1,exec2,exec3)
        
        trans = Puppet::Transaction.new(config)
        execs.each do |e| assert(config.vertex?(e), "%s is not in graph" % e.title) end
        trans.prepare
        execs.each do |e| assert(config.vertex?(e), "%s is not in relgraph" % e.title) end
        reverse = trans.relationship_graph.reversal
        execs.each do |e| assert(reverse.vertex?(e), "%s is not in reversed graph" % e.title) end
        
        config.apply

        assert(FileTest.exists?(file), "File does not exist")

        assert_equal("one\ntwo\nthree\n", File.read(file))
    end
end
