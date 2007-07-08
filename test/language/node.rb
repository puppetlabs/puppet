#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/parser/parser'
require 'puppettest'

class TestParser < Test::Unit::TestCase
    include PuppetTest::ParserTesting

    def setup
        super
        Puppet[:parseonly] = true
    end

    def test_simple_hostname
        check_parseable "host1"
        check_parseable "'host2'"
        check_parseable "\"host3\""
        check_parseable [ "'host1'",  "host2" ]
        check_parseable [ "'host1'",  "'host2'" ]
        check_parseable [ "'host1'",  "\"host2\"" ]
        check_parseable [ "\"host1\"",  "host2" ]
        check_parseable [ "\"host1\"",  "'host2'" ]
        check_parseable [ "\"host1\"",  "\"host2\"" ]
    end

    def test_qualified_hostname
        check_parseable "'host.example.com'"
        check_parseable "\"host.example.com\""
        check_parseable [ "'host.example.com'", "host1" ]
        check_parseable [ "\"host.example.com\"", "host1" ]
        check_parseable "'host-1.37examples.example.com'"
        check_parseable "\"host-1.37examples.example.com\""
        check_parseable "'svn.23.nu'"
        check_parseable "\"svn.23.nu\""
        check_parseable "'HOST'"
        check_parseable "\"HOST\""
    end
    
    def test_inherits_from_default
        check_parseable(["default", "host1"], "node default {}\nnode host1 inherits default {}")
    end

    def test_reject_hostname
        check_nonparseable "host.example.com"
        check_nonparseable "host@example.com"
        check_nonparseable "'$foo.example.com'"
        check_nonparseable "\"$foo.example.com\""
        check_nonparseable "'host1 host2'"
        check_nonparseable "\"host1 host2\""
        check_nonparseable "HOST"
    end

    AST = Puppet::Parser::AST

    def check_parseable(hostnames, code = nil)
        unless hostnames.is_a?(Array)
            hostnames = [ hostnames ]
        end
        interp = nil
        code ||= "node #{hostnames.join(", ")} { }"
        assert_nothing_raised {
            interp = mkinterp :Code => code
        }
        # Strip quotes
        hostnames.map! { |s| s.sub(/^['"](.*)['"]$/, "\\1") }

        # parse
        assert_nothing_raised {
            interp.send(:parsefiles)
        }

        # Now make sure we can look up each of the names
        hostnames.each do |name|
            assert(interp.nodesearch(name),
                "Could not find node %s" % name.inspect)
        end
    end

    def check_nonparseable(hostname)
        interp = nil
        assert_raise(Puppet::DevError, Puppet::ParseError, "#{hostname} passed") {
            interp = mkinterp :Code => "node #{hostname} { }"
            interp.send(:parsefiles)
        }
    end

    # Make sure we can find default nodes if there's no other entry
    def test_default_node
        Puppet[:parseonly] = false

        fileA = tempfile()
        fileB = tempfile()
        code = %{
node mynode {
    file { "#{fileA}": ensure => file }
}

node default {
    file { "#{fileB}": ensure => file }
}
}
        interp = nil
        assert_nothing_raised {
            interp = mkinterp :Code => code
        }

        # First make sure it parses
        assert_nothing_raised {
            interp.send(:parsefiles)
        }

        # Make sure we find our normal node
        assert(interp.nodesearch("mynode"),
            "Did not find normal node")

        # Now look for the default node
        default = interp.nodesearch("someother")
        assert(default,
            "Did not find default node")

        assert_equal("default", default.classname)
    end
end
