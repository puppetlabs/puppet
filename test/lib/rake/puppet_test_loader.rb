
require 'test/unit/autorunner'

ARGV.each { |f| require f unless f =~ /^-/  }

runner = Test::Unit::AutoRunner.new(false)
runner.process_args

runner.run

# $Id$
