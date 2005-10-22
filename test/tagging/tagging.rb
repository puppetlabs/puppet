if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestTagging < Test::Unit::TestCase
    include TestPuppet

    # Make sure the scopes are getting the right tags
    def test_scopetags
        scope = nil
        assert_nothing_raised {
            scope = Puppet::Parser::Scope.new()
            scope.name = "yayness"
            scope.type = "solaris"
        }

        assert_nothing_raised {
            assert_equal(%w{solaris}, scope.tags, "Incorrect scope tags")
        }
    end

    # Test deeper tags, where a scope gets all of its parent scopes' tags
    def test_deepscopetags
        scope = nil
        assert_nothing_raised {
            scope = Puppet::Parser::Scope.new()
            scope.name = "yayness"
            scope.type = "solaris"
            scope = scope.newscope
            scope.name = "booness"
            scope.type = "apache"
        }

        assert_nothing_raised {
            # Scopes put their own tags first
            assert_equal(%w{apache solaris}, scope.tags, "Incorrect scope tags")
        }
    end

    # Verify that the tags make their way to the objects
    def test_objecttags
        scope = nil
        assert_nothing_raised {
            scope = Puppet::Parser::Scope.new()
            scope.name = "yayness"
            scope.type = "solaris"
        }

        assert_nothing_raised {
            scope.setobject(
                "file",
                "/etc/passwd",
                {"owner" => "root"},
                "/yay",
                1
            )
        }

        objects = nil
        assert_nothing_raised {
            objects = scope.to_trans
        }

        # There's only one object, so shift it out
        object = objects.shift

        assert_nothing_raised {
            assert_equal(%w{solaris file /etc/passwd}, object.tags,
                "Incorrect tags")
        }
    end
end

# $Id$
