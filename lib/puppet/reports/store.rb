require 'puppet'

Puppet::Reports.register_report(:store) do
    Puppet.settings.use(:reporting)

    desc "Store the yaml report on disk.  Each host sends its report as a YAML dump
        and this just stores the file on disk, in the ``reportdir`` directory.

        These files collect quickly -- one every half hour -- so it is a good idea
        to perform some maintenance on them if you use this report (it's the only
        default report)."

    def mkclientdir(client, dir)
        config = Puppet::Util::Settings.new
        config.setdefaults("reportclient-#{client}".to_sym,
            "client-#{client}-dir" => { :default => dir,
                :mode => 0750,
                :desc => "Client dir for %s" % client,
                :owner => 'service',
                :group => 'service'
            }
        )

        config.use("reportclient-#{client}".to_sym)
    end

    def process
        # We don't want any tracking back in the fs.  Unlikely, but there
        # you go.
        client = self.host.gsub("..",".")

        dir = File.join(Puppet[:reportdir], client)

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
                f.print to_yaml
            end
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            Puppet.warning "Could not write report for %s at %s: %s" %
                [client, file, detail]
        end

        # Only testing cares about the return value
        return file
    end
end

