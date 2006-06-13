if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parser/parser'
require 'test/unit'
require 'puppettest'

class TestParser < Test::Unit::TestCase
	include ParserTesting

    def setup
        super
        Puppet[:parseonly] = true
        @parser = Puppet::Parser::Parser.new()
    end

    def test_simple_hostname
        check_parseable "host1"
        check_parseable "'host2'"
        check_parseable [ "'host1'",  "host2" ]
        check_parseable [ "'host1'",  "'host2'" ]
    end

    def test_qualified_hostname
        check_parseable "'host.example.com'"
        check_parseable [ "'host.example.com'", "host1" ]
        check_parseable "'host-1.37examples.example.com'"
        check_parseable "'svn.23.nu'"
        check_parseable "'HOST'"
    end

    def test_reject_hostname
        check_nonparseable "host.example.com"
        check_nonparseable "host@example.com"
        check_nonparseable "\"host\""
        check_nonparseable "'$foo.example.com'"
        check_nonparseable "'host1 host2'"
        check_nonparseable "HOST"
    end

    AST = Puppet::Parser::AST

    def check_parseable(hostnames)
        unless hostnames.is_a?(Array)
            hostnames = [ hostnames ]
        end
        assert_nothing_raised {
            @parser.string = "node #{hostnames.join(", ")} { }"
        }
        # Strip quotes
        hostnames.map! { |s| s.sub(/^'(.*)'$/, "\\1") }
        ast = nil
        assert_nothing_raised {
            ast = @parser.parse
        }
        # Verify that the AST has the expected structure
        # and that the leaves have the right hostnames in them
        assert_kind_of(AST::ASTArray, ast)
        assert_equal(1, ast.children.size)
        nodedef = ast.children[0]
        assert_kind_of(AST::NodeDef, nodedef)
        assert_kind_of(AST::ASTArray, nodedef.names)
        assert_equal(hostnames.size, nodedef.names.children.size)
        hostnames.size.times do |i|
            hostnode = nodedef.names.children[i]
            assert_kind_of(AST::HostName, hostnode)
            assert_equal(hostnames[i], hostnode.value)
        end
    end

    def check_nonparseable(hostname)
        assert_nothing_raised {
            @parser.string = "node #{hostname} { }"
        }

        assert_raise(Puppet::DevError, Puppet::ParseError) {
            @parser.parse
        }
    end

    # Make sure we can find default nodes if there's no other entry
    def test_default_node
        Puppet[:parseonly] = false
        @parser = Puppet::Parser::Parser.new()

        fileA = tempfile()
        fileB = tempfile()
        @parser.string = %{
node mynode {
    file { "#{fileA}": ensure => file }
}

node default {
    file { "#{fileB}": ensure => file }
}
}

        # First make sure it parses
        ast = nil
        assert_nothing_raised {
            ast = @parser.parse
        }

        args = {
            :ast => ast,
            :facts => {},
            :names => ["mynode"]
        }
        # Make sure we get a config for "mynode"

        trans = nil
        assert_nothing_raised {
            trans = Puppet::Parser::Scope.new.evaluate(args)
        }

        assert(trans, "Did not get config for mynode")

        args[:names] = ["othernode"]
        # Now make sure the default node is used
        trans = nil
        assert_nothing_raised {
            trans = Puppet::Parser::Scope.new.evaluate(args)
        }

        assert(trans, "Did not get config for default node")
    end
end
