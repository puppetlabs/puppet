# Author: Christian Hofstaedtler <hofstaedtler@inqnet.at>
# Copyright (c) 2007 Luke Kanies, 2008 Christian Hofstaedtler
#
# This file is mostly based on puppetmasterd, which is part of
# the standard puppet distribution.

require 'rack'
require 'puppet'
require 'puppet/network/http_server/rack'

# startup code from bin/puppetmasterd
Puppet.parse_config
Puppet::Util::Log.level = :info
Puppet::Util::Log.newdestination(:syslog)
# A temporary solution, to at least make the master work for now.
Puppet::Node::Facts.terminus_class = :yaml
# Cache our nodes in yaml.  Currently not configurable.
Puppet::Node.cache_class = :yaml

# The list of handlers running inside this puppetmaster
handlers = {
	:Status => {},
	:FileServer => {},
	:Master => {},
	:CA => {},
	:FileBucket => {},
	:Report => {}
}

# Fire up the Rack-Server instance
server = Puppet::Network::HTTPServer::Rack.new(handlers)

# prepare the rack app
app = proc do |env|
	server.process(env)
end

# Go.
run app

