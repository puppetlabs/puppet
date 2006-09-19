require 'puppet'
require 'puppet/filetype'
require 'puppettest'

class TestFileType < Test::Unit::TestCase
	include PuppetTest

    def test_flat
        obj = nil
        path = tempfile()
        type = nil

        assert_nothing_raised {
            type = Puppet::FileType.filetype(:flat)
        }

        assert(type, "Could not retrieve flat filetype")

        assert_nothing_raised {
            obj = type.new(path)
        }

        text = "This is some text\n"

        newtext = nil
        assert_nothing_raised {
            newtext = obj.read
        }

        # The base class doesn't allow a return of nil
        assert_equal("", newtext, "Somehow got some text")

        assert_nothing_raised {
            obj.write(text)
        }
        assert_nothing_raised {
            newtext = obj.read
        }

        assert_equal(text, newtext, "Text was changed somehow")

        File.open(path, "w") { |f| f.puts "someyayness" }

        text = File.read(path)
        assert_nothing_raised {
            newtext = obj.read
        }

        assert_equal(text, newtext, "Text was changed somehow")
    end

    if Facter["operatingsystem"].value == "Darwin"
    def test_ninfotoarray
        obj = nil
        type = nil

        assert_nothing_raised {
            type = Puppet::FileType.filetype(:netinfo)
        }

        assert(type, "Could not retrieve netinfo filetype")
        %w{users groups aliases}.each do |map|
            assert_nothing_raised {
                obj = type.new(map)
            }

            assert_nothing_raised("could not read map %s" % map) {
                obj.read
            }

            array = nil

            assert_nothing_raised {
                array = obj.to_array
            }

            assert_instance_of(Array, array)

            array.each do |record|
                assert_instance_of(Hash, record)
                assert(record.length != 0)
            end
        end
    end
    end
end

# $Id$
