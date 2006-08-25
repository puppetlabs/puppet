require 'xmlrpc/server'

module Puppet
class Server
    class ServletError < RuntimeError; end
    class Servlet < XMLRPC::WEBrickServlet
        ERR_UNAUTHORIZED = 30

        attr_accessor :request

        # this is just a duplicate of the normal method; it's here for
        # debugging when i need it
        def self.get_instance(server, *options)
            self.new(server, *options)
        end

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

        def add_handler(interface, handler)
            @loadedhandlers << interface.prefix
            super
        end

        # Verify that our client has access.  We allow untrusted access to
        # puppetca methods but no others.
        def authorize(request, method)
            namespace = method.sub(/\..+/, '')
            client = request.peeraddr[2]
            if defined? @client and @client
                client = @client
            end
            ip = request.peeraddr[3]
            if request.client_cert
                begin
                if @puppetserver.authconfig.exists?
                    allowed = @puppetserver.authconfig.allowed?(method, client, ip)

                    if allowed
                        Puppet.debug "Allowing %s(%s) trusted access to %s" %
                            [client, ip, method]
                        return true
                    else
                        Puppet.debug "Denying %s(%s) trusted access to %s" %
                            [client, ip, method]
                        return false
                    end
                else
                    # This is pretty hackish, but...
                    # This means we can't actually test this method at this point.
                    # The next release of Puppet will almost definitely require
                    # this file to exist or will default to denying all access.
                    if Puppet.name == "puppetmasterd" or defined? Test::Unit::TestCase
                        Puppet.debug "Allowing %s(%s) trusted access to %s" %
                            [client, ip, method]
                        return true
                    else
                        Puppet.debug "Denying %s(%s) trusted access to %s on %s" %
                            [client, ip, method, Puppet.name]
                        return false
                    end
                end
                rescue => detail
                    puts detail
                    puts detail.backtrace
                    raise
                end
            else
                if method =~ /^puppetca\./
                    Puppet.notice "Allowing %s(%s) untrusted access to CA methods" %
                        [client, ip]
                else
                    Puppet.err "Unauthenticated client %s(%s) cannot call %s" %
                        [client, ip, method]
                    return false
                end
            end
        end

        def available?(method)
            namespace = method.sub(/\..+/, '')
            client = request.peeraddr[2]
            ip = request.peeraddr[3]
            if @loadedhandlers.include?(namespace)
                return true
            else
                Puppet.warning "Client %s(%s) requested unavailable functionality %s" %
                    [client, ip, namespace]
                return false
            end
        end

        def initialize(server, handlers)
            @puppetserver = server
            @notified = {}
            # the servlet base class does not consume any arguments
            # and its BasicServer base class only accepts a 'class_delim'
            # option which won't change in Puppet at all
            # thus, we don't need to pass any args to our base class,
            # and we can consume them all ourselves
            super()

            @loadedhandlers = []
            handlers.each { |handler|
                #Puppet.debug "adding handler for %s" % handler.class
                self.add_handler(handler.class.interface, handler)
            }

            # Initialize these to nil, but they will get set to values
            # by the 'service' method.  These have to instance variables
            # because I don't have a clear line from the service method to
            # the service hook.
            @request = nil
            @client = nil
            @clientip = nil

            self.set_service_hook { |obj, *args|
                if @client and @clientip
                    args.push(@client, @clientip)
                end
                begin
                    obj.call(*args)
                rescue XMLRPC::FaultException
                    raise
                rescue Puppet::Server::AuthorizationError => detail
                    #Puppet.warning obj.inspect
                    #Puppet.warning args.inspect
                    Puppet.err "Permission denied: %s" % detail.to_s
                    raise XMLRPC::FaultException.new(
                        1, detail.to_s
                    )
                rescue Puppet::Error => detail
                    #Puppet.warning obj.inspect
                    #Puppet.warning args.inspect
                    Puppet.err detail.to_s
                    raise XMLRPC::FaultException.new(
                        1, detail.to_s
                    )
                rescue => detail
                    #Puppet.warning obj.inspect
                    #Puppet.warning args.inspect
                    puts detail.inspect
                    Puppet.err "Could not call: %s" % detail.to_s
                    raise XMLRPC::FaultException.new(1, detail.to_s)
                end
            }
        end

        # Handle the actual request.  This does some basic collection of
        # data, and then just calls the parent method.
        def service(request, response)
            @request = request

            # The only way that @client can be nil is if the request is local.
            if peer = request.peeraddr
                @client = peer[2]
                @clientip = peer[3]
            else
                raise XMLRPC::FaultException.new(
                    ERR_UNCAUGHT_EXCEPTION,
                    "Could not retrieve client information"
                )
            end

            # If they have a certificate (which will almost always be true)
            # then we get the hostname from the cert, instead of via IP
            # info
            if cert = request.client_cert
                nameary = cert.subject.to_a.find { |ary|
                    ary[0] == "CN"
                }   

                if nameary.nil?
                    Puppet.warning "Could not retrieve server name from cert"
                else
                    unless @client == nameary[1]
                        Puppet.debug "Overriding %s with cert name %s" %
                            [@client, nameary[1]]
                        @client = nameary[1]
                    end
                end
            end
            begin
                super
            rescue => detail
                Puppet.err "Could not service request: %s: %s" %
                    [detail.class, detail]
            end
            @client = nil
            @clientip = nil
            @request = nil
        end

        private

        # this is pretty much just a copy of the original method but with more
        # feedback
        # here's where we have our authorization hooks
        def dispatch(methodname, *args)

            if defined? @request and @request
                unless self.available?(methodname)
                    raise XMLRPC::FaultException.new(
                        ERR_UNAUTHORIZED,
                        "Functionality %s not available" %
                            methodname.sub(/\..+/, '')
                    )
                end
                unless self.authorize(@request, methodname)
                    raise XMLRPC::FaultException.new(
                        ERR_UNAUTHORIZED,
                        "Host %s not authorized to call %s" %
                            [@request.host, methodname]
                    )
                end
            else
                raise Puppet::DevError, "Did not get request in dispatch"
            end

            #Puppet.warning "dispatch on %s called with %s" %
            #    [methodname, args.inspect]
            for name, obj in @handler
                if obj.kind_of? Proc
                    unless methodname == name
                        #Puppet.debug "obj is proc but %s != %s" %
                        #    [methodname, name]
                        next
                    end
                else
                    unless methodname =~ /^#{name}(.+)$/
                        #Puppet.debug "methodname did not match"
                        next
                    end
                    unless obj.respond_to? $1
                        #Puppet.debug "methodname does not respond to %s" % $1
                        next
                    end
                    obj = obj.method($1)
                end

                if check_arity(obj, args.size)
                    if @service_hook.nil?
                        return obj.call(*args) 
                    else
                        return @service_hook.call(obj, *args)
                    end
                else
                    Puppet.debug "arity is incorrect"
                end
            end 

            if @default_handler.nil?
                raise XMLRPC::FaultException.new(
                    ERR_METHOD_MISSING,
                    "Method #{methodname} missing or wrong number of parameters!"
                )
            else
                @default_handler.call(methodname, *args) 
            end
        end
    end
end
end
