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

            # build our AST
            @file = hash[:File] || Puppet[:manifest]
            @parser = Puppet::Parser::Parser.new()
            @parser.file = @file
            @ast = @parser.parse
            hash.delete(:File)

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

        def getconfig(facts, request = nil)
            if request
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
    end
end
end
