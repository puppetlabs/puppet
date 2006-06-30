require 'puppet'

Puppet.config.setdefaults(:reporting,
    :tagmap => ["$confdir/tagmap.conf",
        "The mapping between reporting tags and email addresses."],
    :sendmail => [%x{which sendmail 2>/dev/null}.chomp,
        "Where to find the sendmail binary with which to send email."],
    :reportfrom => ["report@" + [Facter["hostname"].value, Facter["domain"].value].join("."),
        "The 'from' email address for the reports."],
    :smtpserver => ["none",
        "The server through which to send email reports."]
)

require 'net/smtp'

Puppet::Server::Report.newreport(:tagmail) do |report|
    unless FileTest.exists?(Puppet[:tagmap])
        Puppet.notice "Cannot send tagmail report; not tagmap file %s" %
            Puppet[:tagmap]
        return
    end

    # Load the config file
    tags = {}
    File.readlines(Puppet[:tagmap]).each do |line|
        taglist, emails = line.chomp.split(/\s*:\s*/)

        emails = emails.split(/\s*,\s*/)
        taglist.split(/\s*,\s*/).each do |tag|
            tags[tag] = emails
        end
    end

    # Now find any appropriately tagged messages.
    reports = {}
    tags.each do |tag, emails|
        messages = nil
        if tag == "all"
            messages = report.logs
        else
            messages = report.logs.find_all do |log|
                log.tagged?(tag)
            end
        end

        if messages and ! messages.empty?
            reports[emails] = messages.collect { |m| m.to_report }.join("\n")
        end
    end

    if Puppet[:smtpserver] != "none"
        begin
            Net::SMTP.start(Puppet[:smtpserver]) do |smtp|
                reports.each do |emails, messages|
                    Puppet.info "Sending report to %s" % emails.join(", ")
                    smtp.send_message(messages, Puppet[:reportfrom], *emails)
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
                Puppet.info "Sending report to %s" % emails.join(", ")
                # We need to open a separate process for every set of email addresses
                IO.popen(Puppet[:sendmail] + " " + emails.join(" "), "w") do |p|
                    p.puts "From: #{Puppet[:reportfrom]}\nSubject: Puppet Report"
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
