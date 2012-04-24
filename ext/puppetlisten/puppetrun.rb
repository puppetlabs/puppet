#! /usr/bin/env ruby
# this scripts calls a client and ask him to trigger a puppetd run
# uses SSL for communication based on the puppet infrastructure
# the client allows access based on the namespaceauth
# ohadlevy@gmail.com

port = 8139
if ARGV[0].nil?
  warn "Usage: hostname to run against"
  exit 1
else
  host = ARGV[0]
end

require 'puppet/sslcertificates/support'
require 'socket'

# load puppet configuration, needed to find ssl certificates
Puppet.initialize_settings

# establish the certificate
ctx = OpenSSL::SSL::SSLContext.new
ctx.key = OpenSSL::PKey::RSA.new(File::read(Puppet[:hostprivkey]))
ctx.cert = OpenSSL::X509::Certificate.new(File::read(Puppet[:hostcert]))
ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
ctx.ca_file = Puppet[:localcacert]

# establish the connection
s = TCPSocket.new(host, port)
ssl = OpenSSL::SSL::SSLSocket.new(s, ctx)
ssl.connect # start SSL session
ssl.sync_close = true  # if true the underlying socket will be
#                        closed in SSLSocket#close. (default: false)
while (line = ssl.gets)
  puts line
end

ssl.close
