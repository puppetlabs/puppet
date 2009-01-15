#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppettest'
require 'puppet/util/filetype'
require 'mocha'

class TestFileType < Test::Unit::TestCase
	include PuppetTest
    if Facter["operatingsystem"].value == "Darwin"
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

