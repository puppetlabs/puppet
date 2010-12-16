require 'puppet'
require 'puppet/indirector'

# A class for reporting what happens on each client.  Reports consist of
# two types of data:  Logs and Metrics.  Logs are the output that each
# change produces, and Metrics are all of the numerical data involved
# in the transaction.
class Puppet::Transaction::Report
  extend Puppet::Indirector

  indirects :report, :terminus_class => :processor

  attr_reader :resource_statuses, :logs, :metrics, :host, :time, :kind

  # This is necessary since Marshall doesn't know how to
  # dump hash with default proc (see below @records)
  def self.default_format
    :yaml
  end

  def <<(msg)
    @logs << msg
    self
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

  def initialize(kind = "apply")
    @metrics = {}
    @logs = []
    @resource_statuses = {}
    @external_times ||= {}
    @host = Puppet[:certname]
    @time = Time.now
    @kind = kind
  end

  def name
    host
  end

  # Provide a human readable textual summary of this report.
  def summary
    report = raw_summary

    ret = ""
    report.keys.sort { |a,b| a.to_s <=> b.to_s }.each do |key|
      ret += "#{Puppet::Util::Metric.labelize(key)}:\n"

      report[key].keys.sort { |a,b|
        # sort by label
        if a == :total
          1
        elsif b == :total
          -1
        else
          report[key][a].to_s <=> report[key][b].to_s
        end
      }.each do |label|
        value = report[key][label]
        next if value == 0
        value = "%0.2f" % value if value.is_a?(Float)
        ret += "   %15s %s\n" % [Puppet::Util::Metric.labelize(label) + ":", value]
      end
    end
    ret
  end

  # Provide a raw hash summary of this report.
  def raw_summary
    report = {}

    @metrics.each do |name, metric|
      key = metric.name.to_s
      report[key] = {}
      metric.values.each do |name, label, value|
        report[key][name.to_s] = value
      end
      report[key]["total"] = 0 unless key == "time" or report[key].include?("total")
    end
    (report["time"] ||= {})["last_run"] = Time.now.tv_sec
    report
  end

  # Based on the contents of this report's metrics, compute a single number
  # that represents the report. The resulting number is a bitmask where
  # individual bits represent the presence of different metrics.
  def exit_status
    status = 0
    status |= 2 if @metrics["changes"][:total] > 0
    status |= 4 if @metrics["resources"][:failed] > 0
    status
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
