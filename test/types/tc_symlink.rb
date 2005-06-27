if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'

# $Id$

class TestSymlink < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        @symlink = nil
        @path = File.join($puppetbase,"examples/root/etc/symlink")

        Kernel.system("rm -f %s" % @path)
        Puppet[:debug] = 1
        assert_nothing_raised() {
            unless Puppet::Type::Symlink.has_key?(@path)
                Puppet::Type::Symlink.new(
                    :path => @path
                )
            end
            @symlink = Puppet::Type::Symlink[@path]
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
