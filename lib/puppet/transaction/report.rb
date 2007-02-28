require 'puppet'

# A class for reporting what happens on each client.  Reports consist of
# two types of data:  Logs and Metrics.  Logs are the output that each
# change produces, and Metrics are all of the numerical data involved
# in the transaction.
class Puppet::Transaction::Report
    attr_accessor :logs, :metrics, :time, :host
    
    def <<(msg)
        @logs << msg
        return self
    end

    def initialize
        @metrics = {}
        @logs = []

        @records = Hash.new do |hash, key|
            hash[key] = []
        end

        domain = Facter.value("domain")
        hostname = Facter.value("hostname")
        if !domain || domain.empty? then
            @host = hostname
        else
            @host = [hostname, domain].join(".")
        end
    end

    # Create a new metric.
    def newmetric(name, hash)
        metric = Puppet::Util::Metric.new(name)

        hash.each do |name, value|
            metric.newvalue(name, value)
        end

        @metrics[metric.name] = metric
    end

    # Add a new log message.
    def newlog(msg)
        @logs << msg
    end

    def record(metric, object)
        @records[metric] << object
    end
end

# $Id$
