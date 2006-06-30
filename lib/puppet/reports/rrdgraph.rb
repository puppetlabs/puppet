require 'puppet'

Puppet::Server::Report.newreport(:rrdgraph) do |report|
    time = Time.now.to_i

    File.open(File.join(Puppet[:rrddir],"index.html"),"w") { |of|
        of.puts "<html><body>"
        report.metrics.each do |name, metric|
            metric.store(time)

            metric.graph

            of.puts "<img src=%s.png><br>" % name
        end

        of.puts "</body></html>"
    }
end

# $Id$
