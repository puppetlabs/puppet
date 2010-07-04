require 'puppet'
require 'pp'

require 'net/smtp'
require 'time'

Puppet::Reports.register_report(:tagmail) do
    desc "This report sends specific log messages to specific email addresses
        based on the tags in the log messages.  See the
        `UsingTags tag documentation`:trac: for more information
        on tags.

        To use this report, you must create a ``tagmail.conf`` (in the location
        specified by ``tagmap``).  This is a simple file that maps tags to
        email addresses:  Any log messages in the report that match the specified
        tags will be sent to the specified email addresses.

        Tags must be comma-separated, and they can be negated so that messages
        only match when they do not have that tag.  The tags are separated from
        the email addresses by a colon, and the email addresses should also
        be comma-separated.

        Lastly, there is an ``all`` tag that will always match all log messages.

        Here is an example tagmail.conf::

            all: me@domain.com
            webserver, !mailserver: httpadmins@domain.com

        This will send all messages to ``me@domain.com``, and all messages from
        webservers that are not also from mailservers to ``httpadmins@domain.com``.

        If you are using anti-spam controls, such as grey-listing, on your mail
        server you should whitelist the sending email (controlled by ``reportform``
        configuration option) to ensure your email is not discarded as spam.
        "


    # Find all matching messages.
    def match(taglists)
        reports = []
        taglists.each do |emails, pos, neg|
            # First find all of the messages matched by our positive tags
            messages = nil
            if pos.include?("all")
                messages = self.logs
            else
                # Find all of the messages that are tagged with any of our
                # tags.
                messages = self.logs.find_all do |log|
                    pos.detect { |tag| log.tagged?(tag) }
                end
            end

            # Now go through and remove any messages that match our negative tags
            messages = messages.reject do |log|
                if neg.detect do |tag| log.tagged?(tag) end
                    true
                end
            end

            if messages.empty?
                Puppet.info "No messages to report to %s" % emails.join(",")
                next
            else
                reports << [emails, messages.collect { |m| m.to_report }.join("\n")]
            end
        end

        return reports
    end

    # Load the config file
    def parse(text)
        taglists = []
        text.split("\n").each do |line|
            taglist = emails = nil
            case line.chomp
            when /^\s*#/; next
            when /^\s*$/; next
            when /^\s*(.+)\s*:\s*(.+)\s*$/
                taglist = $1
                emails = $2.sub(/#.*$/,'')
            else
                raise ArgumentError, "Invalid tagmail config file"
            end

            pos = []
            neg = []
            taglist.sub(/\s+$/,'').split(/\s*,\s*/).each do |tag|
                unless tag =~ /^!?[-\w]+$/
                    raise ArgumentError, "Invalid tag %s" % tag.inspect
                end
                case tag
                when /^\w+/; pos << tag
                when /^!\w+/; neg << tag.sub("!", '')
                else
                    raise Puppet::Error, "Invalid tag '%s'" % tag
                end
            end

            # Now split the emails
            emails = emails.sub(/\s+$/,'').split(/\s*,\s*/)
            taglists << [emails, pos, neg]
        end
        return taglists
    end

    # Process the report.  This just calls the other associated messages.
    def process
        unless FileTest.exists?(Puppet[:tagmap])
            Puppet.notice "Cannot send tagmail report; no tagmap file %s" %
                Puppet[:tagmap]
            return
        end

        taglists = parse(File.read(Puppet[:tagmap]))

        # Now find any appropriately tagged messages.
        reports = match(taglists)

        send(reports)
    end

    # Send the email reports.
    def send(reports)
        pid = fork do
            if Puppet[:smtpserver] != "none"
                begin
                    Net::SMTP.start(Puppet[:smtpserver]) do |smtp|
                        reports.each do |emails, messages|
                            smtp.open_message_stream(Puppet[:reportfrom], *emails) do |p|
                              p.puts "From: #{Puppet[:reportfrom]}"
                              p.puts "Subject: Puppet Report for %s" % self.host
                              p.puts "To: " + emails.join(", ")
                              p.puts "Date: " + Time.now.rfc2822
                              p.puts
                              p.puts messages
                            end
                        end
                    end
                rescue => detail
                    if Puppet[:debug]
                        puts detail.backtrace
                    end
                    raise Puppet::Error,
                        "Could not send report emails through smtp: %s" % detail
                end
            elsif Puppet[:sendmail] != ""
                begin
                    reports.each do |emails, messages|
                        # We need to open a separate process for every set of email addresses
                        IO.popen(Puppet[:sendmail] + " " + emails.join(" "), "w") do |p|
                            p.puts "From: #{Puppet[:reportfrom]}"
                            p.puts "Subject: Puppet Report for %s" % self.host
                            p.puts "To: " + emails.join(", ")

                            p.puts messages
                        end
                    end
                rescue => detail
                    if Puppet[:debug]
                        puts detail.backtrace
                    end
                    raise Puppet::Error,
                        "Could not send report emails via sendmail: %s" % detail
                end
            else
                raise Puppet::Error, "SMTP server is unset and could not find sendmail"
            end
        end

        # Don't bother waiting for the pid to return.
        Process.detach(pid)
    end
end

