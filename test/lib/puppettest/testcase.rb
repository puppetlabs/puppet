#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-03-05.
#  Copyright (c) 2007. All rights reserved.

require 'puppettest'
require 'puppettest/runnable_test'
require 'test/unit'

class PuppetTest::TestCase < Test::Unit::TestCase
  include PuppetTest
  extend PuppetTest::RunnableTest

  def self.suite
    # Always skip this parent class.  It'd be nice if there were a
    # "supported" way to do this.
    if self == PuppetTest::TestCase
      suite = Test::Unit::TestSuite.new(name)
      return suite
    elsif self.runnable?
      return super
    else
      puts "Skipping #{name}: #{@messages.join(", ")}" if defined? $console
      suite = Test::Unit::TestSuite.new(name)
      return suite
    end
  end
end
