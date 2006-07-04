require 'puppet'

# A class for reporting what happens on each client.  Reports consist of
# two types of data:  Logs and Metrics.  Logs are the output that each
# change produces, and Metrics are all of the numerical data involved
# in the transaction.
class Puppet::Transaction::Report
    attr_accessor :logs, :metrics, :time, :host

    def initialize
        @metrics = {}
        @logs = []

        @records = Hash.new do |hash, key|
            hash[key] = []
        end

        @host = [Facter.value("hostname"), Facter.value("domain")].join(".")
    end

    # Create a new metric.
    def newmetric(name, hash)
        metric = Puppet::Metric.new(name)

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
