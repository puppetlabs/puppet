if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parsedfile'
require 'puppettest'
require 'test/unit'

class TestParsedFile < TestPuppet
    def test_file
        file = nil
        path = tempfile()
        File.open(path, "w") { |f| f.puts "yayness" }
        assert_nothing_raised {
            file = Puppet::ParsedFile.new(path)
        }

        assert(!file.changed?, "File incorrectly returned changed")

        sleep(1)
        File.open(path, "w") { |f| f.puts "booness" }

        assert(file.changed?, "File did not catch change")
    end
end

# $Id$
