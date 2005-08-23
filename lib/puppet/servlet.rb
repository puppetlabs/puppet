require 'xmlrpc/server'

module Puppet
    class ServletError < RuntimeError; end
    class Servlet < XMLRPC::WEBrickServlet
        attr_accessor :request

        # this is just a duplicate of the normal method; it's here for
        # debugging when i need it
        def self.get_instance(server, *options)
            self.new(server, *options)
        end

        def initialize(server, handlers)
            #Puppet.info server.inspect
            
            # the servlet base class does not consume any arguments
            # and its BasicServer base class only accepts a 'class_delim'
            # option which won't change in Puppet at all
            # thus, we don't need to pass any args to our base class,
            # and we can consume them all ourselves
            super()

            handlers.each { |handler|
                Puppet.debug "adding handler for %s" % handler.class
                self.add_handler(handler.class.interface, handler)
            }

            @request = nil
            self.set_service_hook { |obj, *args|
                #raise "crap!"
                if @request
                    args.push @request
                    #obj.call(args, @request)
                end
                begin
                    obj.call(*args)
                rescue => detail
                    Puppet.warning obj.inspect
                    Puppet.err "Could not call: %s" % detail.to_s
                end
            }
        end

        def service(request, response)
            @request = request
            if @request.client_cert
                Puppet.info "client cert is %s" % @request.client_cert
            end
            if @request.server_cert
                Puppet.info "server cert is %s" % @request.server_cert
            end
            #p @request
            begin
                super
            rescue => detail
                Puppet.err "Could not service request: %s: %s" %
                    [detail.class, detail]
            end
            @request = nil
        end

        private

        # this is pretty much just a copy of the original method but with more
        # feedback
        def dispatch(methodname, *args)
            #Puppet.warning "dispatch on %s called with %s" %
            #    [methodname, args.inspect]
            for name, obj in @handler
                if obj.kind_of? Proc
                    unless methodname == name
                        Puppet.debug "obj is proc but %s != %s" %
                            [methodname, name]
                        next
                    end
                else
                    unless methodname =~ /^#{name}(.+)$/
                        Puppet.debug "methodname did not match"
                        next
                    end
                    unless obj.respond_to? $1
                        Puppet.debug "methodname does not respond to %s" % $1
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
