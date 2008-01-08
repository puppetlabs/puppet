#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppettest'
require 'puppet/util/filetype'
require 'mocha'

class TestFileType < Test::Unit::TestCase
	include PuppetTest

    def test_flat
        obj = nil
        path = tempfile()
        type = nil

        assert_nothing_raised {
            type = Puppet::Util::FileType.filetype(:flat)
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

    # Make sure that modified files are backed up before they're changed.
    def test_backup_is_called
        path = tempfile
        File.open(path, "w") { |f| f.print 'yay' }

        obj = Puppet::Util::FileType.filetype(:flat).new(path)

        obj.expects(:backup)

        obj.write("something")

        assert_equal("something", File.read(path), "File did not get changed")
    end

    def test_backup
        path = tempfile
        type = Puppet::Type.type(:filebucket)

        obj = Puppet::Util::FileType.filetype(:flat).new(path)

        # First try it when the file does not yet exist.
        assert_nothing_raised("Could not call backup when file does not exist") do
            obj.backup
        end

        # Then create the file
        File.open(path, "w") { |f| f.print 'one' }

        # Then try it with no filebucket objects
        assert_nothing_raised("Could not call backup with no buckets") do
            obj.backup
        end
        puppet = type.mkdefaultbucket
        assert(puppet, "Did not create default filebucket")

        assert_equal("one", puppet.bucket.getfile(Digest::MD5.hexdigest(File.read(path))), "Could not get file from backup")

        # Try it again when the default already exists
        File.open(path, "w") { |f| f.print 'two' }
        assert_nothing_raised("Could not call backup with no buckets") do
            obj.backup
        end

        assert_equal("two", puppet.bucket.getfile(Digest::MD5.hexdigest(File.read(path))), "Could not get file from backup")
    end

    if Facter["operatingsystem"].value == "Darwin" and Facter["operatingsystemrelease"] != "9.1.0"
    def test_ninfotoarray
        obj = nil
        type = nil

        assert_nothing_raised {
            type = Puppet::Util::FileType.filetype(:netinfo)
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

            assert_nothing_raised("Failed to parse %s map" % map) {
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

