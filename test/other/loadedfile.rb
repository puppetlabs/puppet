require 'puppet'
require 'puppet/loadedfile'
require 'puppettest'

class TestLoadedFile < Test::Unit::TestCase
	include PuppetTest
    def test_file
        Puppet[:filetimeout] = 0
        file = nil
        path = tempfile()
        File.open(path, "w") { |f| f.puts "yayness" }
        assert_nothing_raised {
            file = Puppet::LoadedFile.new(path)
        }

        assert(!file.changed?, "File incorrectly returned changed")

        File.open(path, "w") { |f| f.puts "booness" }
        #file.tstamp = File.stat(path).ctime - 5
        new = File.stat(path).ctime - 5
        file.tstamp = new

        assert(file.changed?, "File did not catch change")
    end

    def test_timeout
        Puppet[:filetimeout] = 50
        path = tempfile()

        File.open(path, "w") { |f| f.puts "yay" }
        file = nil
        assert_nothing_raised {
            file = Puppet::LoadedFile.new(path)
        }

        assert_nothing_raised {
            assert(!file.changed?,
                "File thought it changed immediately")
        }

        sleep 1
        File.open(path, "w") { |f| f.puts "yay" }
        #file.tstamp = File.stat(path).ctime - 5

        assert(!file.changed?,
            "File was marked as changed too soon")

        Puppet[:filetimeout] = 0
        assert(file.changed?,
            "File was not marked as changed soon enough")
    end

    def test_stamp
        file = tempfile()
        File.open(file, "w") { |f| f.puts "" }
        obj = nil
        assert_nothing_raised {
            obj = Puppet::LoadedFile.new(file)
        }

        # Make sure we don't refresh
        Puppet[:filetimeout] = 50

        stamp = File.stat(file).ctime

        assert_equal(stamp, obj.stamp)

        sleep 1
        # Now change the file, and make sure the stamp doesn't update yet
        File.open(file, "w") { |f| f.puts "" }
        assert_equal(stamp, obj.stamp,
            "File prematurely refreshed")

        Puppet[:filetimeout] = 0
        assert_equal(File.stat(file).ctime, obj.stamp,
            "File did not refresh")
    end
end

# $Id$
