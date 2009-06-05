require 'xmlrpc/server'
require 'puppet/network/authorization'
require 'puppet/network/xmlrpc/processor'

module Puppet::Network::XMLRPC
    class ServletError < RuntimeError; end
    class WEBrickServlet < ::XMLRPC::WEBrickServlet
        include Puppet::Network::XMLRPCProcessor

        # This is a hackish way to avoid an auth message every time we have a
        # normal operation
        def self.log(msg)
            unless defined? @logs
                @logs = {}
            end
            if @logs.include?(msg)
                @logs[msg] += 1
            else
                Puppet.info msg
                @logs[msg] = 1
            end
        end

        # Accept a list of handlers and register them all.
        def initialize(handlers)
            # the servlet base class does not consume any arguments
            # and its BasicServer base class only accepts a 'class_delim'
            # option which won't change in Puppet at all
            # thus, we don't need to pass any args to our base class,
            # and we can consume them all ourselves
            super()

            setup_processor()

            # Set up each of the passed handlers.
            handlers.each do |handler|
                add_handler(handler.class.interface, handler)
            end
        end

        # Handle the actual request.  We can't use the super() method, because
        # we need to pass a ClientRequest object to process() so we can do
        # authorization.  It's the only way to stay thread-safe.
        def service(request, response)
            if @valid_ip
                raise WEBrick::HTTPStatus::Forbidden unless @valid_ip.any? { |ip| request.peeraddr[3] =~ ip }
            end

            if request.request_method != "POST"
                raise WEBrick::HTTPStatus::MethodNotAllowed,
                    "unsupported method `#{request.request_method}'."
            end

            if parse_content_type(request['Content-type']).first != "text/xml"
                raise WEBrick::HTTPStatus::BadRequest
            end

            length = (request['Content-length'] || 0).to_i

            raise WEBrick::HTTPStatus::LengthRequired unless length > 0

            data = request.body

            if data.nil? or data.size != length
                raise WEBrick::HTTPStatus::BadRequest
            end

            resp = process(data, client_request(request))
            if resp.nil? or resp.size <= 0
                raise WEBrick::HTTPStatus::InternalServerError
            end

            response.status = 200
            response['Content-Length'] = resp.size
            response['Content-Type']   = "text/xml; charset=utf-8"
            response.body = resp
        end

        private

        # Generate a ClientRequest object for later validation.
        def client_request(request)
            if peer = request.peeraddr
                client = peer[2]
                clientip = peer[3]
            else
                raise ::XMLRPC::FaultException.new(
                    ERR_UNCAUGHT_EXCEPTION,
                    "Could not retrieve client information"
                )
            end

            # If they have a certificate (which will almost always be true)
            # then we get the hostname from the cert, instead of via IP
            # info
            valid = false
            if cert = request.client_cert
                nameary = cert.subject.to_a.find { |ary|
                    ary[0] == "CN"
                }

                if nameary.nil?
                    Puppet.warning "Could not retrieve server name from cert"
                else
                    unless client == nameary[1]
                        Puppet.debug "Overriding %s with cert name %s" %
                            [client, nameary[1]]
                        client = nameary[1]
                    end
                    valid = true
                end
            end

            info = Puppet::Network::ClientRequest.new(client, clientip, valid)

            return info
        end
    end
end

