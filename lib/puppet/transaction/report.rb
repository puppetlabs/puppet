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

    def add_times(name, value)
        @external_times[name] = value
    end

    def add_metric(name, hash)
        metric = Puppet::Util::Metric.new(name)

        hash.each do |name, value|
            metric.newvalue(name, value)
        end

        @metrics[metric.name] = metric
        metric
    end

    def add_resource_status(status)
        @resource_statuses[status.resource] = status
    end

    def calculate_metrics
        calculate_resource_metrics
        calculate_time_metrics
        calculate_change_metrics
        calculate_event_metrics
    end

    def initialize
        @metrics = {}
        @logs = []
        @resource_statuses = {}
        @external_times ||= {}
        @host = Puppet[:certname]
        @time = Time.now
    end

    def name
        host
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

    private

    def calculate_change_metrics
        metrics = Hash.new(0)
        resource_statuses.each do |name, status|
            metrics[:total] += status.change_count if status.change_count
        end

        add_metric(:changes, metrics)
    end

    def calculate_event_metrics
        metrics = Hash.new(0)
        resource_statuses.each do |name, status|
            metrics[:total] += status.events.length
            status.events.each do |event|
                metrics[event.status] += 1
            end
        end

        add_metric(:events, metrics)
    end

    def calculate_resource_metrics
        metrics = Hash.new(0)
        metrics[:total] = resource_statuses.length

        resource_statuses.each do |name, status|

            Puppet::Resource::Status::STATES.each do |state|
                metrics[state] += 1 if status.send(state)
            end
        end

        add_metric(:resources, metrics)
    end

    def calculate_time_metrics
        metrics = Hash.new(0)
        resource_statuses.each do |name, status|
            type = Puppet::Resource.new(name).type
            metrics[type.to_s.downcase] += status.evaluation_time if status.evaluation_time
        end

        @external_times.each do |name, value|
            metrics[name.to_s.downcase] = value
        end

        add_metric(:time, metrics)
    end
end
