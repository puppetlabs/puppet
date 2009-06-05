#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-11-07.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppettest'
require 'puppet/util/feature'

class TestFeatures < Test::Unit::TestCase
    include PuppetTest

    def setup
        super
        @libdir = tempfile()
        Puppet[:libdir] = @libdir
        @path = File.join(@libdir, "features")
        @features = Puppet::Util::Feature.new("features")
    end

    def test_new
        redirect
        assert_nothing_raised do
            @features.add(:failer) do
                raise ArgumentError, "nopes"
            end
        end

        assert(@features.respond_to?(:failer?), "Feature method did not get added")
        assert_nothing_raised("failure propagated outside of feature") do
            assert(! @features.failer?, "failure was considered true")
        end

        # Now make one that succeeds
        $succeeds = nil
        assert_nothing_raised("Failed to add normal feature") do
            @features.add(:succeeds) do
                $succeeds = true
            end
        end
        assert($succeeds, "Block was not called on initialization")

        assert(@features.respond_to?(:succeeds?), "Did not add succeeding feature")
        assert_nothing_raised("Failed to call succeeds") { assert(@features.succeeds?, "Feature was not true") }
    end

    def test_libs
        assert_nothing_raised do
            @features.add(:puppet, :libs => %w{puppet})
        end

        assert(@features.puppet?)

        assert_nothing_raised do
            @features.add(:missing, :libs => %w{puppet no/such/library/okay})
        end

        assert(! @features.missing?, "Missing lib was considered true")
    end

    def test_dynamic_loading
        # Make sure it defaults to false
        assert_nothing_raised("Undefined features throw an exception") do
            assert(! @features.nosuchfeature?, "missing feature returned true")
        end

        $features = @features
        cleanup { $features = nil }
        # Now create a feature and make sure it loads.
        FileUtils.mkdir_p(@path)
        nope = File.join(@path, "nope.rb")
        File.open(nope, "w") { |f|
            f.puts "$features.add(:nope, :libs => %w{nosuchlib})"
        }
        assert_nothing_raised("Failed to autoload features") do
            assert(! @features.nope?, "'nope' returned true")
        end

        # First make sure "yep?" returns false
        assert_nothing_raised("Missing feature threw an exception") do
            assert(! @features.yep?, "'yep' returned true before definition")
        end

        yep = File.join(@path, "yep.rb")
        File.open(yep, "w") { |f|
            f.puts "$features.add(:yep, :libs => %w{puppet})"
        }

        # Now make sure the value is not cached or anything.
        assert_nothing_raised("Failed to autoload features") do
            assert(@features.yep?, "'yep' returned false")
        end
    end
end
