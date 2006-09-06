if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/loadedfile'
require 'puppettest'
require 'test/unit'

class TestLoadedFile < Test::Unit::TestCase
	include TestPuppet
    def test_file
        Puppet[:filetimeout] = 0
        file = nil
        path = tempfile()
        File.open(path, "w") { |f| f.puts "yayness" }
        assert_nothing_raised {
            file = Puppet::LoadedFile.new(path)
        }

        assert(!file.changed?, "File incorrectly returned changed")

        #sleep(1)
        File.open(path, "w") { |f| f.puts "booness" }
        file.send("tstamp=".intern, File.stat(path).ctime - 5)

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

        assert_nothing_raised { file.changed? }

        File.open(path, "w") { |f| f.puts "yay" }
        file.send("tstamp=".intern, File.stat(path).ctime - 5)

        assert(!file.changed?,
            "File was marked as changed too soon")

        Puppet[:filetimeout] = 0
        assert(file.changed?,
            "File was not marked as changed soon enough")


    end
end

# $Id$
