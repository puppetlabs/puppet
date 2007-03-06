#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-11-24.
#  Copyright (c) 2006. All rights reserved.

require 'puppettest'

class PuppetTest::TestCase < Test::Unit::TestCase
    def self.confine(hash)
        @confines ||= {}
        hash.each do |message, result|
            @confines[message] = result
        end
    end

    def self.runnable?
        @messages ||= []
        return false unless @messages.empty?
        return true unless defined? @confines
        @confines.find_all do |message, result|
            ! result
        end.each do |message, result|
            @messages << message
        end

        return @messages.empty?
    end

    def self.suite
        # Always skip this parent class.  It'd be nice if there were a
        # "supported" way to do this.
        if self == PuppetTest::TestCase
            suite = Test::Unit::TestSuite.new(name)
            return suite
        elsif self.runnable?
            return super
        else
            if defined? $console
                puts "Skipping %s: %s" % [name, @messages.join(", ")]
            end
            suite = Test::Unit::TestSuite.new(name)
            return suite
        end
    end
end

# $Id$
