# a config.ru, for use with every rack-compatible webserver.
# SSL needs to be handled outside this, though.

# if puppet is not in your RUBYLIB:
# $:.unshift('/opt/puppet/lib')

$0 = "puppetmasterd"
require 'puppet'

# if you want debugging:
# ARGV << "--debug"

ARGV << "--rack"
require 'puppet/application/puppetmasterd'
# we're usually running inside a Rack::Builder.new {} block,
# therefore we need to call run *here*.
run Puppet::Application[:puppetmasterd].run

