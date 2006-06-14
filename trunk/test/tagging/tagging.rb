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
                :type => "file",
                :name => "/etc/passwd",
                :arguments => {"owner" => "root"},
                :file => "/yay",
                :line => 1
            )
        }

        objects = nil
        assert_nothing_raised {
            objects = scope.to_trans
        }

        # There's only one object, so shift it out
        object = objects.shift

        assert_nothing_raised {
            assert_equal(%w{solaris}, object.tags,
                "Incorrect tags")
        }
    end

    # Make sure that specifying tags results in only those objects getting
    # run.
    def test_tagspecs
        a = tempfile()
        b = tempfile()

        afile = Puppet.type(:file).create(
            :path => a,
            :ensure => :file
        )
        afile.tag("a")

        bfile = Puppet.type(:file).create(
            :path => b,
            :ensure => :file
        )
        bfile.tag(:b)

        # First, make sure they get created when no spec'ed tags
        assert_events([:file_created,:file_created], afile, bfile)
        assert(FileTest.exists?(a), "A did not get created")
        assert(FileTest.exists?(b), "B did not get created")
        File.unlink(a)
        File.unlink(b)

        # Set the tags to a
        assert_nothing_raised {
            Puppet[:tags] = "a"
        }

        assert_events([:file_created], afile, bfile)
        assert(FileTest.exists?(a), "A did not get created")
        assert(!FileTest.exists?(b), "B got created")
        File.unlink(a)

        # Set the tags to b
        assert_nothing_raised {
            Puppet[:tags] = "b"
        }

        assert_events([:file_created], afile, bfile)
        assert(!FileTest.exists?(a), "A got created")
        assert(FileTest.exists?(b), "B did not get created")
        File.unlink(b)

        # Set the tags to something else
        assert_nothing_raised {
            Puppet[:tags] = "c"
        }

        assert_events([], afile, bfile)
        assert(!FileTest.exists?(a), "A got created")
        assert(!FileTest.exists?(b), "B got created")

        # Now set both tags
        assert_nothing_raised {
            Puppet[:tags] = "b, a"
        }

        assert_events([:file_created, :file_created], afile, bfile)
        assert(FileTest.exists?(a), "A did not get created")
        assert(FileTest.exists?(b), "B did not get created")
        File.unlink(a)

    end

    def test_metaparamtag
        path = tempfile()

        start = %w{some tags}
        tags = %w{a list of tags}

        obj = nil
        assert_nothing_raised do
            obj = Puppet.type(:file).create(
                :path => path,
                :ensure => "file",
                :tag => start
            )
        end


        assert(obj, "Did not make object")

        start.each do |tag|
            assert(obj.tagged?(tag), "Object was not tagged with %s" % tag)
        end

        tags.each do |tag|
            assert_nothing_raised {
                obj[:tag] = tag
            }
        end

        tags.each do |tag|
            assert(obj.tagged?(tag), "Object was not tagged with %s" % tag)
        end
    end
end

# $Id$
