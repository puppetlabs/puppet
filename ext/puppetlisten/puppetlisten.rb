#! /usr/bin/env ruby
# this is a daemon which accepts non standard (within puppet normal intervals) puppet configruation run request
# uses SSL for communication based on the puppet infrastructure
# ohadlevy@gmail.com

port = 8139
cmd = "puppetd -o -v --no-daemonize"

require 'puppet/sslcertificates/support'
require 'socket'
require 'facter'

# load puppet configuration, needed to find SSL certificates
Puppet.initialize_settings

# set the SSL environment
ctx = OpenSSL::SSL::SSLContext.new
ctx.key = OpenSSL::PKey::RSA.new(File::read(Puppet[:hostprivkey]))
ctx.cert = OpenSSL::X509::Certificate.new(File::read(Puppet[:hostcert]))
ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER|OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
ctx.ca_file = Puppet[:localcacert]

# find which hosts are allowed to trigger us
allowed_servers = Array.new
runner = false;
File.open(Puppet[:authconfig]).each do |line|
  case line
  when /^\s*#/
    next # skip comments
  when /^\s*$/
    next # skip blank lines
  when /\[puppetrunner\]/ # puppetrunner section
    runner=true
  when /^\s*(\w+)\s+(.+)$/
    var = $1
    value = $2
    case var
    when "allow"
      value.split(/\s*,\s*/).each { |val|
      allowed_servers << val
      puts "allowing #{val} access"
    } if runner==true
    end
  else
    runner=false
  end
end

# be a daemon
sock = TCPServer.new(port)
ssls = OpenSSL::SSL::SSLServer.new(sock, ctx)

loop do
  begin
    ns = ssls.accept # start SSL session
    af, port, host, ip = ns.peeraddr
    print "connection from #{host+"("+ip+")"} "
    if allowed_servers.include?(host)
      #TODO add support for tags and other command line arguments
      puts "accepted"
      ns.puts "Executing #{cmd} on #{Facter.fqdn}.\n*******OUTPUT********\n\n"
      IO.popen(cmd) do |f|
        while line = f.gets
          ns.puts line
        end
      end
      ns.puts "\n*********DONE**********"
    else
      ns.puts "denied\n"
      puts "denied"
    end
    ns.close
  rescue
    ns.close
    next
  end
end
