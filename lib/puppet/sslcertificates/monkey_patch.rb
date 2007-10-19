# This is the file that we use to add indirection to all the SSL Certificate classes.

require 'puppet/indirector'

OpenSSL::PKey::RSA.extend Puppet::Indirector
OpenSSL::PKey::RSA.indirects :ssl_rsa, :terminus_class => :file
