require 'puppet'
require 'puppet/indirector'

# A class for reporting what happens on each client.  Reports consist of
# two types of data:  Logs and Metrics.  Logs are the output that each
# change produces, and Metrics are all of the numerical data involved
# in the transaction.
class Puppet::Transaction::Report
    extend Puppet::Indirector

    indirects :report, :terminus_class => :processor

    attr_accessor :logs, :metrics, :time, :host

    # This is necessary since Marshall doesn't know how to
    # dump hash with default proc (see below @records)
    def self.default_format
        :yaml
    end

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

        @host = Puppet[:certname]
    end

    def name
        host
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

    # Provide a summary of this report.
    def summary
        ret = ""

        @metrics.sort { |a,b| a[1].label <=> b[1].label }.each do |name, metric|
            ret += "%s:\n" % metric.label
            metric.values.sort { |a,b|
                # sort by label
                if a[0] == :total
                    1
                elsif b[0] == :total
                    -1
                else
                    a[1] <=> b[1]
                end
            }.each do |name, label, value|
                next if value == 0
                if value.is_a?(Float)
                    value = "%0.2f" % value
                end
                ret += "   %15s %s\n" % [label + ":", value]
            end
        end
        return ret
    end
end

