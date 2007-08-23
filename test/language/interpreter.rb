#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'facter'

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/network/client'
require 'puppettest'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'
require 'puppettest/servertest'
require 'timeout'

class TestInterpreter < PuppetTest::TestCase
	include PuppetTest
    include PuppetTest::ServerTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    AST = Puppet::Parser::AST

    # create a simple manifest that uses nodes to create a file
    def mknodemanifest(node, file)
        createdfile = tempfile()

        File.open(file, "w") { |f|
            f.puts "node %s { file { \"%s\": ensure => file, mode => 755 } }\n" %
                [node, createdfile]
        }

        return [file, createdfile]
    end

    def test_reloadfiles
        node = mknode(Facter["hostname"].value)

        file = tempfile()

        # Create a first version
        createdfile = mknodemanifest(node.name, file)

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(:Manifest => file)
        }

        config = nil
        assert_nothing_raised {
            config = interp.compile(node)
        }
        Puppet[:filetimeout] = -5

        # Now create a new file
        createdfile = mknodemanifest(node.name, file)

        newconfig = nil
        assert_nothing_raised {
            newconfig = interp.compile(node)
        }

        assert(config != newconfig, "Configs are somehow the same")
    end

    def test_parsedate
        Puppet[:filetimeout] = 0
        main = tempfile()
        sub = tempfile()
        mainfile = tempfile()
        subfile = tempfile()
        count = 0
        updatemain = proc do
            count += 1
            File.open(main, "w") { |f|
                f.puts "import '#{sub}'
                    file { \"#{mainfile}\": content => #{count} }
                    "
            }
        end
        updatesub = proc do
            count += 1
            File.open(sub, "w") { |f|
                f.puts "file { \"#{subfile}\": content => #{count} }
                "
            }
        end

        updatemain.call
        updatesub.call

        interp = Puppet::Parser::Interpreter.new(
            :Manifest => main,
            :Local => true
        )

        date = interp.parsedate

        # Now update the site file and make sure we catch it
        sleep 1
        updatemain.call
        newdate = interp.parsedate
        assert(date != newdate, "Parsedate was not updated")
        date = newdate

        # And then the subfile
        sleep 1
        updatesub.call
        newdate = interp.parsedate
        assert(date != newdate, "Parsedate was not updated")
    end

    # Make sure our whole chain works.
    def test_compile
        interp = mkinterp
        interp.expects(:parsefiles)
        parser = interp.instance_variable_get("@parser")

        node = mock('node')
        config = mock('config')
        config.expects(:compile).returns(:config)
        Puppet::Parser::Configuration.expects(:new).with(node, parser, :ast_nodes => interp.usenodes).returns(config)
        assert_equal(:config, interp.compile(node), "Did not return the results of config.compile")
    end

    # Make sure that reparsing is atomic -- failures don't cause a broken state, and we aren't subject
    # to race conditions if someone contacts us while we're reparsing.
    def test_atomic_reparsing
        Puppet[:filetimeout] = -10
        file = tempfile
        File.open(file, "w") { |f| f.puts %{file { '/tmp': ensure => directory }} }
        interp = mkinterp :Manifest => file, :UseNodes => false

        assert_nothing_raised("Could not compile the first time") do
            interp.compile(mknode("yay"))
        end

        oldparser = interp.send(:instance_variable_get, "@parser")

        # Now add a syntax failure
        File.open(file, "w") { |f| f.puts %{file { /tmp: ensure => directory }} }
        assert_nothing_raised("Could not compile the first time") do
            interp.compile(mknode("yay"))
        end

        # And make sure the old parser is still there
        newparser = interp.send(:instance_variable_get, "@parser")
        assert_equal(oldparser.object_id, newparser.object_id, "Failed parser still replaced existing parser")
    end
end

# $Id$
