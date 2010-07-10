
require 'test/unit/autorunner'
require 'getoptlong'
require 'puppettest'

args = PuppetTest.munge_argv

args.each { |f| require f unless f =~ /^-/  }

runner = Test::Unit::AutoRunner.new(false)
runner.process_args

exit 14 unless runner.run

