#!/usr/bin/env ruby

require 'test/unit/autorunner'

runner = Test::Unit::AutoRunner.new(false)
runner.process_args

ARGV.each { |f| load f unless f =~ /^-/  }

runner.run

# $Id$
