if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../.."
end

require 'blink'
require 'test/unit'

# $Id$

class TestSymlink < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        @symlink = nil
        @path = File.join($blinkbase,"examples/root/etc/symlink")

        Kernel.system("rm -f %s" % @path)
        Blink[:debug] = 1
        assert_nothing_raised() {
            unless Blink::Type::Symlink.has_key?(@path)
                Blink::Type::Symlink.new(
                    :path => @path
                )
            end
            @symlink = Blink::Type::Symlink[@path]
        }
    end

    def test_target
        assert_nothing_raised() {
            @symlink[:target] = "configfile"
        }
        assert_nothing_raised() {
            @symlink.retrieve
        }
        # we might already be in sync
        assert(!@symlink.insync?())
        assert_nothing_raised() {
            @symlink.sync
        }
        assert_nothing_raised() {
            @symlink.retrieve
        }
        assert(@symlink.insync?())
        assert_nothing_raised() {
            @symlink[:target] = nil
        }
        assert_nothing_raised() {
            @symlink.retrieve
        }
        assert(!@symlink.insync?())
        assert_nothing_raised() {
            @symlink.sync
        }
        assert_nothing_raised() {
            @symlink.retrieve
        }
        assert(@symlink.insync?())
    end

    def teardown
        Kernel.system("rm -f %s" % @path)
    end
end
