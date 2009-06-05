#!/usr/bin/env ruby
# File:       06-11-14-mongrel_xmlrpc.rb
# Author:     Manuel Holtgrewe <purestorm at ggnore.net>
#
# Copyright (c) 2006 Manuel Holtgrewe, 2007 Luke Kanies
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

# This file is based heavily on a file retrieved from
# http://ttt.ggnore.net/2006/11/15/xmlrpc-with-mongrel-and-ruby-off-rails/

require 'rubygems'
require 'mongrel'
require 'xmlrpc/server'
require 'puppet/network/xmlrpc/server'
require 'puppet/network/http_server'
require 'puppet/network/client_request'
require 'puppet/network/handler'

require 'resolv'

# This handler can be hooked into Mongrel to accept HTTP requests. After
# checking whether the request itself is sane, the handler forwards it
# to an internal instance of XMLRPC::BasicServer to process it.
#
# You can access the server by calling the Handler's "xmlrpc_server"
# attribute accessor method and add XMLRPC handlers there. For example:
#
# <pre>
# handler = XmlRpcHandler.new
# handler.xmlrpc_server.add_handler("my.add") { |a, b| a.to_i + b.to_i }
# </pre>
module Puppet::Network
    class HTTPServer::Mongrel < ::Mongrel::HttpHandler
        attr_reader :xmlrpc_server

        def initialize(handlers)
            if Puppet[:debug]
                $mongrel_debug_client = true
                Puppet.debug 'Mongrel client debugging enabled. [$mongrel_debug_client = true].'
            end
            # Create a new instance of BasicServer. We are supposed to subclass it
            # but that does not make sense since we would not introduce any new
            # behaviour and we have to subclass Mongrel::HttpHandler so our handler
            # works for Mongrel.
            @xmlrpc_server = Puppet::Network::XMLRPCServer.new
            handlers.each do |name|
                unless handler = Puppet::Network::Handler.handler(name)
                    raise ArgumentError, "Invalid handler %s" % name
                end
                @xmlrpc_server.add_handler(handler.interface, handler.new({}))
            end
        end

        # This method produces the same results as XMLRPC::CGIServer.serve
        # from Ruby's stdlib XMLRPC implementation.
        def process(request, response)
            # Make sure this has been a POST as required for XMLRPC.
            request_method = request.params[Mongrel::Const::REQUEST_METHOD] || Mongrel::Const::GET
            if request_method != "POST" then
                response.start(405) { |head, out| out.write("Method Not Allowed") }
                return
            end

            # Make sure the user has sent text/xml data.
            request_mime = request.params["CONTENT_TYPE"] || "text/plain"
            if parse_content_type(request_mime).first != "text/xml" then
                response.start(400) { |head, out| out.write("Bad Request") }
                return
            end

            # Make sure there is data in the body at all.
            length = request.params[Mongrel::Const::CONTENT_LENGTH].to_i
            if length <= 0 then
                response.start(411) { |head, out| out.write("Length Required") }
                return
            end

            # Check the body to be valid.
            if request.body.nil? or request.body.size != length then
                response.start(400) { |head, out| out.write("Bad Request") }
                return
            end

            info = client_info(request)

            # All checks above passed through
            response.start(200) do |head, out|
                head["Content-Type"] = "text/xml; charset=utf-8"
                begin
                    out.write(@xmlrpc_server.process(request.body, info))
                rescue => detail
                    puts detail.backtrace
                    raise
                end
            end
        end

        private

        def client_info(request)
            params = request.params
            ip = params["HTTP_X_FORWARDED_FOR"] ? params["HTTP_X_FORWARDED_FOR"].split(',').last.strip : params["REMOTE_ADDR"]
            # JJM #906 The following dn.match regular expression is forgiving
            # enough to match the two Distinguished Name string contents
            # coming from Apache, Pound or other reverse SSL proxies.
            if dn = params[Puppet[:ssl_client_header]] and dn_matchdata = dn.match(/^.*?CN\s*=\s*(.*)/)
                client = dn_matchdata[1].to_str
                valid = (params[Puppet[:ssl_client_verify_header]] == 'SUCCESS')
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

        # Taken from XMLRPC::ParseContentType
        def parse_content_type(str)
            a, *b = str.split(";")
            return a.strip, *b
        end
    end
end

