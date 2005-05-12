if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../../../../language/trunk"
end

require 'blink'
require 'test/unit'

# $Id$

class TestFile < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        @file = nil
        @path = File.join($blinkbase,"examples/root/etc/configfile")
        Blink[:debug] = 1
        assert_nothing_raised() {
            unless Blink::Type::File.has_key?(@path)
                Blink::Type::File.new(
                    :path => @path
                )
            end
            @file = Blink::Type::File[@path]
        }
    end

    def test_owner
        [Process.uid,%x{whoami}.chomp].each { |user|
            assert_nothing_raised() {
                @file[:owner] = user
            }
            assert_nothing_raised() {
                @file.retrieve
            }
            assert_nothing_raised() {
                @file.sync
            }
            assert_nothing_raised() {
                @file.retrieve
            }
            assert(@file.insync?())
        }
        assert_nothing_raised() {
            @file[:owner] = "root"
        }
        assert_nothing_raised() {
            @file.retrieve
        }
        # we might already be in sync
        assert(!@file.insync?())
        assert_nothing_raised() {
            @file.delete(:owner)
        }
    end

    def test_group
        [%x{groups}.chomp.split(/ /), Process.groups].flatten.each { |group|
            puts "Testing %s" % group
            assert_nothing_raised() {
                @file[:group] = group
            }
            assert_nothing_raised() {
                @file.retrieve
            }
            assert_nothing_raised() {
                @file.sync
            }
            assert_nothing_raised() {
                @file.retrieve
            }
            assert(@file.insync?())
            assert_nothing_raised() {
                @file.delete(:group)
            }
        }
    end

    def test_modes
        [0644,0755,0777,0641].each { |mode|
            assert_nothing_raised() {
                @file[:mode] = mode
            }
            assert_nothing_raised() {
                @file.retrieve
            }
            assert_nothing_raised() {
                @file.sync
            }
            assert_nothing_raised() {
                @file.retrieve
            }
            assert(@file.insync?())
            assert_nothing_raised() {
                @file.delete(:mode)
            }
        }
    end
end
