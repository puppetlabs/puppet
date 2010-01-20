require 'puppet'
require 'puppet/indirector'

# A class for reporting what happens on each client.  Reports consist of
# two types of data:  Logs and Metrics.  Logs are the output that each
# change produces, and Metrics are all of the numerical data involved
# in the transaction.
class Puppet::Transaction::Report
    extend Puppet::Indirector

    indirects :report, :terminus_class => :processor

    attr_reader :resource_statuses, :logs, :metrics, :host, :time

    # This is necessary since Marshall doesn't know how to
    # dump hash with default proc (see below @records)
    def self.default_format
        :yaml
    end

    def <<(msg)
        @logs << msg
        return self
    end

    def add_resource_status(status)
        @resource_statuses[status.resource] = status
    end

    def initialize
        @metrics = {}
        @logs = []
        @resource_statuses = {}
        @host = Puppet[:certname]
        @time = Time.now
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

    # Based on the contents of this report's metrics, compute a single number
    # that represents the report. The resulting number is a bitmask where
    # individual bits represent the presence of different metrics.
    def exit_status
        status = 0
        status |= 2 if @metrics["changes"][:total] > 0
        status |= 4 if @metrics["resources"][:failed] > 0
        return status
    end
end
