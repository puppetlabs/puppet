#!/usr/bin/ruby -w

#--------------------
# the puppet client
#
# $Id$


require 'puppet'
require 'puppet/openssl'
require 'getoptlong'

result = GetoptLong.new(
	[ "--debug",	"-d",			GetoptLong::NO_ARGUMENT ],
	[ "--help",		"-h",			GetoptLong::NO_ARGUMENT ]
)

check = false

result.each { |opt,arg|
	case opt
		when "--debug":
		when "--check":
		when "--help":
			puts "There is no help yet"
			exit
		else
			puts "Invalid option '#{opt}'"
            exit(10)
	end
}

Puppet[:logdest] = :console
Puppet[:loglevel] = :info

rootcert = Puppet[:rootcert]
rootkey = Puppet[:rootkey]
rootkey = Puppet[:rootkey]

unless rootcert
     raise "config unset"
end

#mkcertsdir(File.basename(rootcert))
