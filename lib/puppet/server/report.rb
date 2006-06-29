module Puppet
class Server
    # A simple server for triggering a new run on a Puppet client.
    class Report < Handler
        @interface = XMLRPC::Service::Interface.new("puppetrunner") { |iface|
            iface.add_method("string report(array)")
        }

        Puppet.setdefaults(:reporting,
            :reportdirectory => ["$vardir/reports",
                "The directory in which to store reports received from the
                client.  Each client gets a separate subdirectory."]
        )

        def initialize
            Puppet.config.use(:reporting)
        end

        def mkclientdir(client, dir)
            Puppet.config.setdefaults("reportclient-#{client}",
                :clientdir => { :default => dir,
                    :mode => 0750,
                    :owner => "$user",
                    :group => "$group"
                }
            )

            Puppet.config.use("reportclient-#{client}")
        end

        # Accept a report from a client.
        def report(report, client = nil, clientip = nil)
            # We need the client name for storing files.
            client ||= Facter["hostname"].value

            # Unescape the report
            unless @local
                report = CGI.unescape(report)
            end

            # We don't want any tracking back in the fs.  Unlikely, but there
            # you go.
            client.gsub("..",".")

            dir = File.join(Puppet[:reportdirectory], client)

            unless FileTest.exists?(dir)
                mkclientdir(client, dir)
            end

            # Now store the report.
            now = Time.now.gmtime
            name = %w{year month day hour min}.collect do |method|
                # Make sure we're at least two digits everywhere
                "%02d" % now.send(method).to_s
            end.join("") + ".yaml"

            file = File.join(dir, name)

            begin
                File.open(file, "w", 0640) do |f|
                    f.puts report
                end
            rescue => detail
                if Puppet[:debug]
                    puts detail.backtrace
                end
                Puppet.warning "Could not write report for %s at %s: %s" %
                    [client, file, detail]
            end


            # Our report is in YAML
            return file
        end
    end
end
end

# $Id$
