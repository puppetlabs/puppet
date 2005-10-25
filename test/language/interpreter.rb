#!/usr/bin/ruby

if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'test/unit'
require 'puppettest'

class TestInterpreter < Test::Unit::TestCase
	include TestPuppet
    AST = Puppet::Parser::AST

    # create a simple manifest that uses nodes to create a file
    def mknodemanifest(node, file)
        createdfile = tempfile()

        File.open(file, "w") { |f|
            f.puts "node %s { file { \"%s\": create => true, mode => 755 } }\n" %
                [node, createdfile]
        }

        return [file, createdfile]
    end

    def test_simple
        file = tempfile()
        File.open(file, "w") { |f|
            f.puts "file { \"/etc\": owner => root }"
        }
        assert_nothing_raised {
            Puppet::Parser::Interpreter.new(:Manifest => file)
        }
    end

    def test_reloadfiles
        hostname = Facter["hostname"].value

        file = tempfile()

        # Create a first version
        createdfile = mknodemanifest(hostname, file)

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(:Manifest => file)
        }

        config = nil
        assert_nothing_raised {
            config = interp.run(hostname, {})
        }
        sleep(1)

        # Now create a new file
        createdfile = mknodemanifest(hostname, file)

        newconfig = nil
        assert_nothing_raised {
            newconfig = interp.run(hostname, {})
        }

        assert(config != newconfig, "Configs are somehow the same")
    end
end
