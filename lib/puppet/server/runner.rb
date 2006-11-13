module Puppet
class Server
    class MissingMasterError < RuntimeError # Cannot find the master client
    end
    # A simple server for triggering a new run on a Puppet client.
    class Runner < Handler
        @interface = XMLRPC::Service::Interface.new("puppetrunner") { |iface|
            iface.add_method("string run(string, string)")
        }

        # Run the client configuration right now, optionally specifying
        # tags and whether to ignore schedules
        def run(tags = nil, ignoreschedules = false, fg = true, client = nil, clientip = nil)
            # We need to retrieve the client
            master = Puppet::Client::MasterClient.instance

            unless master
                raise MissingMasterError, "Could not find the master client"
            end

            if master.locked?
                Puppet.notice "Could not trigger run; already running"
                return "running"
            end

            if tags == ""
                tags = nil
            end

            if ignoreschedules == ""
                ignoreschedules == nil
            end

            msg = ""
            if client
                msg = "%s(%s) " % [client, clientip]
            end
            msg += "triggered run" %
            if tags
                msg += " with tags %s" % tags
            end

            if ignoreschedules
                msg += " without schedules"
            end

            Puppet.notice msg

            # And then we need to tell it to run, with this extra info.
            if fg
                master.run(tags, ignoreschedules)
            else
                Puppet.newthread do
                    master.run(tags, ignoreschedules)
                end
            end

            return "success"
        end
    end
end
end

# $Id$
