require 'openssl'
require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/sslcertificates'
require 'xmlrpc/server'

module Puppet
class Server
    class MasterError < Puppet::Error; end
    class Master < Handler
        attr_accessor :ast, :local
        attr_reader :ca

        @interface = XMLRPC::Service::Interface.new("puppetmaster") { |iface|
                iface.add_method("string getconfig(string)")
        }

        def initialize(hash = {})

            # FIXME this should all be s/:File/:Manifest/g or something
            # build our AST
            @file = hash[:File] || Puppet[:manifest]
            hash.delete(:File)

            @filestamp = nil
            @filetimeout = hash[:FileTimeout] || 60
            parsefile

            if hash[:Local]
                @local = hash[:Local]
            else
                @local = false
            end

            if hash.include?(:CA) and hash[:CA]
                @ca = Puppet::SSLCertificates::CA.new()
            else
                @ca = nil
            end
        end

        def getconfig(facts, client = nil, clientip = nil)
            parsefile
            if client
                #Puppet.warning request.inspect
            end
            if @local
                # we don't need to do anything, since we should already
                # have raw objects
                Puppet.debug "Our client is local"
            else
                Puppet.debug "Our client is remote"

                # XXX this should definitely be done in the protocol, somehow
                begin
                    facts = Marshal::load(CGI.unescape(facts))
                rescue => detail
                    puts "AAAAA"
                    puts detail
                    exit
                end
            end

            Puppet.debug("Creating interpreter")

            begin
                interpreter = Puppet::Parser::Interpreter.new(
                    :ast => @ast,
                    :facts => facts
                )
            rescue => detail
                return detail.to_s
            end

            Puppet.debug("Running interpreter")
            begin
                retobjects = interpreter.run()
            rescue => detail
                Puppet.err detail.to_s
                return ""
            end

            if @local
                return retobjects
            else
                return CGI.escape(Marshal::dump(retobjects))
            end
        end

        private

        def parsefile
            if @filestamp and FileTest.exists?(@file)
                if @filetimeout and @filestatted and
                    (Time.now - @filestatted > @filetimeout)
                        tmp = File.stat(@file).ctime

                        @filestatted = Time.now
                        if tmp == @filestamp
                            return
                        else
                            Puppet.notice "Reloading file"
                        end
                end
            end

            unless FileTest.exists?(@file)
                if @ast
                    Puppet.warning "Manifest %s has disappeared" % @file
                    return
                else
                    raise Puppet::Error, "Manifest %s must exist" % @file
                end
            end
            # should i be creating a new parser each time...?
            @parser = Puppet::Parser::Parser.new()
            @parser.file = @file
            @ast = @parser.parse

            @filestamp = File.stat(@file).ctime
        end
    end
end
end
