module Puppet
class Server # :nodoc:
    class LoggerError < RuntimeError; end

    # Receive logs from remote hosts.
    class Logger < Handler
        @interface = XMLRPC::Service::Interface.new("puppetlogger") { |iface|
            iface.add_method("void addlog(string)")
        }

        # accept a log message from a client, and route it accordingly
        def addlog(message, client = nil, clientip = nil)
            # if the client is set, then we're not local
            if client
                begin
                    message = Marshal::load(CGI.unescape(message))
                    #message = message
                rescue => detail
                    raise XMLRPC::FaultException.new(
                        1, "Could not unMarshal log message from %s" % client
                    )
                end
            end

            # Mark it as remote, so it's not sent to syslog
            message.remote = true

            if client
                if ! message.source or message.source == "Puppet"
                    message.source = client
                end
            end

            Puppet::Log.newmessage(message)

            # This is necessary or XMLRPC gets all pukey
            return ""
        end
    end
end
end

# $Id$
