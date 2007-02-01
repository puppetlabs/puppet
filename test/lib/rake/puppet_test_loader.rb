
require 'test/unit/autorunner'
require 'getoptlong'

result = GetoptLong.new(
    [ "--debug",    "-d",           GetoptLong::NO_ARGUMENT ],
    [ "-n",                         GetoptLong::REQUIRED_ARGUMENT ],
    [ "--help",     "-h",           GetoptLong::NO_ARGUMENT ]
)

ARGV.each { |f| require f unless f =~ /^-/  }

runner = Test::Unit::AutoRunner.new(false)
runner.process_args

runner.run

# $Id$
