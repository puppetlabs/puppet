$:.unshift '../lib' if __FILE__ == $0 # Make this library first!

require 'blink'
require 'test/unit'

# $Id$

class TestSymlink < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        @symlink = nil
        @path = "../examples/root/etc/symlink"

        Kernel.system("rm -f %s" % @path)
        Blink[:debug] = 1
        assert_nothing_raised() {
            unless Blink::Objects::Symlink.has_key?(@path)
                Blink::Objects::Symlink.new(
                    :path => @path
                )
            end
            @symlink = Blink::Objects::Symlink[@path]
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
end
