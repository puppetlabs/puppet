require 'puppet'
require 'puppet/indirector'

# This class is used to report what happens on a client.
# There are two types of data in a report; _Logs_ and _Metrics_.
#
# * **Logs** - are the output that each change produces.
# * **Metrics** - are all of the numerical data involved in the transaction.
#
# Use {Puppet::Reports} class to create a new custom report type. This class is indirectly used
# as a source of data to report in such a registered report.
#
# ##Metrics
# There are three types of metrics in each report, and each type of metric has one or more values.
#
# * Time: Keeps track of how long things took.
#   * Total: Total time for the configuration run
#   * File:
#   * Exec:
#   * User:
#   * Group:
#   * Config Retrieval: How long the configuration took to retrieve
#   * Service:
#   * Package:
# * Resources: Keeps track of the following stats:
#   * Total: The total number of resources being managed
#   * Skipped: How many resources were skipped, because of either tagging or scheduling restrictions
#   * Scheduled: How many resources met any scheduling restrictions
#   * Out of Sync: How many resources were out of sync
#   * Applied: How many resources were attempted to be fixed
#   * Failed: How many resources were not successfully fixed
#   * Restarted: How many resources were restarted because their dependencies changed
#   * Failed Restarts: How many resources could not be restarted
# * Changes: The total number of changes in the transaction.
#
# @api public
class Puppet::Transaction::Report
  extend Puppet::Indirector

  indirects :report, :terminus_class => :processor

  # The version of the configuration
  # @todo Uncertain what this is?
  # @return [???] the configuration version
  attr_accessor :configuration_version

  # An agent generated transaction uuid, useful for connecting catalog and report
  # @return [String] uuid
  attr_accessor :transaction_uuid

  # The id of the code input to the compiler.
  attr_accessor :code_id

  # A master generated catalog uuid, useful for connecting a single catalog to multiple reports.
  attr_accessor :catalog_uuid

  # Whether a cached catalog was used in the run, and if so, the reason that it was used.
  # @return [String] One of the values: 'not_used', 'explicitly_requested',
  # or 'on_failure'
  attr_accessor :cached_catalog_status

  # The host name for which the report is generated
  # @return [String] the host name
  attr_accessor :host

  # The name of the environment the host is in
  # @return [String] the environment name
  attr_accessor :environment

  # A hash with a map from resource to status
  # @return [Hash{String => Puppet::Resource::Status}] Resource name to status.
  attr_reader :resource_statuses

  # A list of log messages.
  # @return [Array<Puppet::Util::Log>] logged messages
  attr_reader :logs

  # A hash of metric name to metric value.
  # @return [Hash<{String => Object}>] A map of metric name to value.
  # @todo Uncertain if all values are numbers - now marked as Object.
  #
  attr_reader :metrics

  # The time when the report data was generated.
  # @return [Time] A time object indicating when the report data was generated
  #
  attr_reader :time

  # The 'kind' of report is the name of operation that triggered the report to be produced.
  # Typically "apply".
  # @return [String] the kind of operation that triggered the generation of the report.
  #
  attr_reader :kind

  # The status of the client run is an enumeration: 'failed', 'changed' or 'unchanged'
  # @return [String] the status of the run - one of the values 'failed', 'changed', or 'unchanged'
  #
  attr_reader :status

  # @return [String] The Puppet version in String form.
  # @see Puppet::version()
  #
  attr_reader :puppet_version

  # @return [Integer] report format version number.  This value is constant for
  #    a given version of Puppet; it is incremented when a new release of Puppet
  #    changes the API for the various objects that make up a report.
  #
  attr_reader :report_format

  def self.from_data_hash(data)
    obj = self.allocate
    obj.initialize_from_hash(data)
    obj
  end

  def as_logging_destination(&block)
    Puppet::Util::Log.with_destination(self, &block)
  end

  # @api private
  def <<(msg)
    @logs << msg
    self
  end

  # @api private
  def add_times(name, value)
    @external_times[name] = value
  end

  # @api private
  def add_metric(name, hash)
    metric = Puppet::Util::Metric.new(name)

    hash.each do |metric_name, value|
      metric.newvalue(metric_name, value)
    end

    @metrics[metric.name] = metric
    metric
  end

  # @api private
  def add_resource_status(status)
    @resource_statuses[status.resource] = status
  end

  # @api private
  def compute_status(resource_metrics, change_metric)
    if (resource_metrics["failed"] || 0) > 0
      'failed'
    elsif change_metric > 0
      'changed'
    else
      'unchanged'
    end
  end

  # @api private
  def prune_internal_data
    resource_statuses.delete_if {|name,res| res.resource_type == 'Whit'}
  end

  # @api private
  def finalize_report
    prune_internal_data

    resource_metrics = add_metric(:resources, calculate_resource_metrics)
    add_metric(:time, calculate_time_metrics)
    change_metric = calculate_change_metric
    add_metric(:changes, {"total" => change_metric})
    add_metric(:events, calculate_event_metrics)
    @status = compute_status(resource_metrics, change_metric)
  end

  # @api private
  def initialize(kind, configuration_version=nil, environment=nil, transaction_uuid=nil)
    @metrics = {}
    @logs = []
    @resource_statuses = {}
    @external_times ||= {}
    @host = Puppet[:node_name_value]
    @time = Time.now
    @kind = kind
    @report_format = 5
    @puppet_version = Puppet.version
    @configuration_version = configuration_version
    @transaction_uuid = transaction_uuid
    @code_id = nil
    @catalog_uuid = nil
    @cached_catalog_status = nil
    @environment = environment
    @status = 'failed' # assume failed until the report is finalized
  end

  # @api private
  def initialize_from_hash(data)
    @puppet_version = data['puppet_version']
    @report_format = data['report_format']
    @configuration_version = data['configuration_version']
    @transaction_uuid = data['transaction_uuid']
    @environment = data['environment']
    @status = data['status']
    @host = data['host']
    @time = data['time']

    if catalog_uuid = data['catalog_uuid']
      @catalog_uuid = catalog_uuid
    end

    if code_id = data['code_id']
      @code_id = code_id
    end

    if cached_catalog_status = data['cached_catalog_status']
      @cached_catalog_status = cached_catalog_status
    end

    if @time.is_a? String
      @time = Time.parse(@time)
    end
    @kind = data['kind']

    @metrics = {}
    data['metrics'].each do |name, hash|
      @metrics[name] = Puppet::Util::Metric.from_data_hash(hash)
    end

    @logs = data['logs'].map do |record|
      Puppet::Util::Log.from_data_hash(record)
    end

    @resource_statuses = {}
    data['resource_statuses'].map do |record|
      if record[1] == {}
        status = nil
      else
        status = Puppet::Resource::Status.from_data_hash(record[1])
      end
      @resource_statuses[record[0]] = status
    end
  end

  def to_data_hash
    {
      'host' => @host,
      'time' => @time.iso8601(9),
      'configuration_version' => @configuration_version,
      'transaction_uuid' => @transaction_uuid,
      'catalog_uuid' => @catalog_uuid,
      'code_id' => @code_id,
      'cached_catalog_status' => @cached_catalog_status,
      'report_format' => @report_format,
      'puppet_version' => @puppet_version,
      'kind' => @kind,
      'status' => @status,
      'environment' => @environment,

      'logs' => @logs,
      'metrics' => @metrics,
      'resource_statuses' => @resource_statuses,
    }
  end

  # @return [String] the host name
  # @api public
  #
  def name
    host
  end

  # Provide a human readable textual summary of this report.
  # @note This is intended for debugging purposes
  # @return [String] A string with a textual summary of this report.
  # @api public
  #
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

  # Provides a raw hash summary of this report.
  # @return [Hash<{String => Object}>] A hash with metrics key to value map
  # @api public
  #
  def raw_summary
    report = { "version" => { "config" => configuration_version, "puppet" => Puppet.version  } }

    @metrics.each do |name, metric|
      key = metric.name.to_s
      report[key] = {}
      metric.values.each do |metric_name, label, value|
        report[key][metric_name.to_s] = value
      end
      report[key]["total"] = 0 unless key == "time" or report[key].include?("total")
    end
    (report["time"] ||= {})["last_run"] = Time.now.tv_sec
    report
  end

  # Computes a single number that represents the report's status.
  # The computation is based on the contents of this report's metrics.
  # The resulting number is a bitmask where
  # individual bits represent the presence of different metrics.
  #
  # * 0x2 set if there are changes
  # * 0x4 set if there are resource failures or resources that failed to restart
  # @return [Integer] A bitmask where 0x2 is set if there are changes, and 0x4 is set of there are failures.
  # @api public
  #
  def exit_status
    status = 0
    status |= 2 if @metrics["changes"]["total"] > 0
    status |= 4 if @metrics["resources"]["failed"] > 0
    status |= 4 if @metrics["resources"]["failed_to_restart"] > 0
    status
  end

  # @api private
  #
  def to_yaml_properties
    super - [:@external_times]
  end

  def self.supported_formats
    [:pson, :yaml]
  end

  def self.default_format
    :pson
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
