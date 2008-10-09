# Author: Christian Hofstaedtler <hofstaedtler@inqnet.at>
# Copyright (c) 2006 Manuel Holtgrewe, 2007 Luke Kanies,
#               2008 Christian Hofstaedtler
#
# This file is mostly based on the mongrel module, which is part of
# the standard puppet distribution.
#
# puppet/network/http_server/mongrel.rb has the following license, 
# and is based heavily on a file retrieved from:
# http://ttt.ggnore.net/2006/11/15/xmlrpc-with-mongrel-and-ruby-off-rails/
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


require 'puppet'
require 'puppet/network/handler'
require 'puppet/sslcertificates'

require 'xmlrpc/server'
require 'puppet/network/xmlrpc/server'
require 'puppet/network/http_server'
require 'puppet/network/client_request'
require 'puppet/network/handler'

require 'resolv'
require 'rack'

# A handler for a Rack-style puppet(master)d. For the most part, it works 
# exactly the same as HTTPServer::Mongrel:
# After checking whether the request itself is sane, the handler forwards 
# it to an internal instance of XMLRPC::BasicServer to process it.
module Puppet::Network
	class HTTPServer::Rack
		attr_reader :xmlrpc_server

		def initialize(handlers)
			@debug = false
			if Puppet[:debug]
				@debug = true
			end

			Puppet.info "Starting Rack server for puppet version %s" % Puppet.version
			if Puppet[:name] != "puppetmasterd" then
				Puppet.warn 'Rack server is not named "puppetmasterd", this may be not what you want. ($0 = %s)' % $0
			end

			@xmlrpc_server = Puppet::Network::XMLRPCServer.new
			handlers.each do |name, args|
				unless handler = Puppet::Network::Handler.handler(name)
					raise ArgumentError, "Invalid handler %s" % name
				end
				h = handler.new(args)
				@xmlrpc_server.add_handler(handler.interface, h)
			end
			Puppet.info "Rack server is waiting to serve requests."
		end

		# Validate a rack-style request (in env), and run the requested XMLRPC
		# call.
		def process(env)
			# time to serve a request
			req = Rack::Request.new(env)

			if @debug then
				Puppet.info "Handling request, details:"
				env.each do |name, val|
					l = "  env: %s ->" % name
					l = l + ' %s' % val
					Puppet.info l
				end
			end

			if not req.post? then
				return [405, { "Content-Type" => "text/html" }, "Method Not Allowed"]
			end
			if req.media_type() != "text/xml" then
				return [400, { "Content-Type" => "text/html" }, "Bad Request"]
			end
			if req.content_length().to_i <= 0 then
				return [411, { "Content-Type" => "text/html" }, "Length Required"]
			end

			body = ''
			req.body().each { |line| body = body + line }
			if @debug then
				Puppet.info "Request Body: %s" % body
			end
			if body.size != req.content_length().to_i then
				if @debug then
					Puppet.info "body length didnt match %d" % body.size
					Puppet.info " vs. -> %d" % req.content_length().to_i
				end
				return [400, { "Content-Type" => "text/html" }, "Bad Request Length"]
			end
			info = client_info(env)
			begin
				data = @xmlrpc_server.process(body, info)
				return [200, { "Content-Type" => "text/xml; charset=utf-8" }, data]
			rescue => detail
				Puppet.err "Rack: Internal Server Error: XMLRPC_Server.process problem. Details follow: "
				detail.backtrace.each { |line| 	Puppet.err " --> %s" % line }
				return [500, { "Content-Type" => "text/html" }, "Internal Server Error"]
			end
		end

		private

		def client_info(request)
			ip = request["REMOTE_ADDR"]
			# JJM #906 The following dn.match regular expression is forgiving
			# enough to match the two Distinguished Name string contents
			# coming from Apache, Pound or other reverse SSL proxies.
			if dn = request[Puppet[:ssl_client_header]] and dn_matchdata = dn.match(/^.*?CN\s*=\s*(.*)/)
				client = dn_matchdata[1].to_str
				valid = (request[Puppet[:ssl_client_verify_header]] == 'SUCCESS')
			else
				begin
					client = Resolv.getname(ip)
				rescue => detail
					Puppet.err "Could not resolve %s: %s" % [ip, detail]
					client = "unknown"
				end
				valid = false
			end
			info = Puppet::Network::ClientRequest.new(client, ip, valid)
			return info
		end
	end
end

