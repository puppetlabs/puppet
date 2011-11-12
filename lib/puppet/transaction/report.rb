require 'puppet'
require 'puppet/indirector'

# A class for reporting what happens on each client.  Reports consist of
# two types of data:  Logs and Metrics.  Logs are the output that each
# change produces, and Metrics are all of the numerical data involved
# in the transaction.
class Puppet::Transaction::Report
  extend Puppet::Indirector

  indirects :report, :terminus_class => :processor

  attr_accessor :configuration_version, :host
  attr_reader :resource_statuses, :logs, :metrics, :time, :kind, :status

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

  def compute_status(resource_metrics, change_metric)
    if (resource_metrics["failed"] || 0) > 0
      'failed'
    elsif change_metric > 0
      'changed'
    else
      'unchanged'
    end
  end

  def prune_internal_data
    resource_statuses.delete_if {|name,res| res.resource_type == 'Whit'}
  end

  def finalize_report
    prune_internal_data

    resource_metrics = add_metric(:resources, calculate_resource_metrics)
    add_metric(:time, calculate_time_metrics)
    change_metric = calculate_change_metric
    add_metric(:changes, {"total" => change_metric})
    add_metric(:events, calculate_event_metrics)
    @status = compute_status(resource_metrics, change_metric)
  end

  def initialize(kind, configuration_version=nil)
    @metrics = {}
    @logs = []
    @resource_statuses = {}
    @external_times ||= {}
    @host = Puppet[:node_name_value]
    @time = Time.now
    @kind = kind
    @report_format = 2
    @puppet_version = Puppet.version
    @configuration_version = configuration_version
    @status = 'failed' # assume failed until the report is finalized
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
    report = { "version" => { "config" => configuration_version, "puppet" => Puppet.version  } }

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
    status |= 2 if @metrics["changes"]["total"] > 0
    status |= 4 if @metrics["resources"]["failed"] > 0
    status
  end

  def to_yaml_properties
    (instance_variables - ["@external_times"]).sort
  end

  private

  def calculate_change_metric
    resource_statuses.map { |name, status| status.change_count || 0 }.inject(0) { |a,b| a+b }
  end

  def calculate_event_metrics
    metrics = Hash.new(0)
    %w{total failure success}.each { |m| metrics[m] = 0 }
    resource_statuses.each do |name, status|
      metrics["total"] += status.events.length
      status.events.each do |event|
        metrics[event.status] += 1
      end
    end

    metrics
  end

  def calculate_resource_metrics
    metrics = {}
    metrics["total"] = resource_statuses.length

    # force every resource key in the report to be present
    # even if no resources is in this given state
    Puppet::Resource::Status::STATES.each do |state|
      metrics[state.to_s] = 0
    end

    resource_statuses.each do |name, status|
      Puppet::Resource::Status::STATES.each do |state|
        metrics[state.to_s] += 1 if status.send(state)
      end
    end

    metrics
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

    metrics["total"] = metrics.values.inject(0) { |a,b| a+b }

    metrics
  end
end
