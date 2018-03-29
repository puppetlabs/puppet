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
  include Puppet::Util::PsychSupport
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

  # The id of the job responsible for this run.
  attr_accessor :job_id

  # A master generated catalog uuid, useful for connecting a single catalog to multiple reports.
  attr_accessor :catalog_uuid

  # Whether a cached catalog was used in the run, and if so, the reason that it was used.
  # @return [String] One of the values: 'not_used', 'explicitly_requested',
  # or 'on_failure'
  attr_accessor :cached_catalog_status

  # Contains the name and port of the master that was successfully contacted
  # @return [String] a string of the format 'servername:port'
  attr_accessor :master_used

  # The host name for which the report is generated
  # @return [String] the host name
  attr_accessor :host

  # The name of the environment the host is in
  # @return [String] the environment name
  attr_accessor :environment

  # Whether there are changes that we decided not to apply because of noop
  # @return [Boolean]
  #
  attr_accessor :noop_pending

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

  # Whether the puppet run was started in noop mode
  # @return [Boolean]
  #
  attr_reader :noop

  # @!attribute [r] corrective_change
  #   @return [Boolean] true if the report contains any events and resources that had
  #      corrective changes.
  attr_reader :corrective_change

  # @return [Boolean] true if one or more resources attempted to generate
  #   resources and failed
  #
  attr_accessor :resources_failed_to_generate

  # @return [Boolean] true if the transaction completed it's evaluate
  #
  attr_accessor :transaction_completed

  TOTAL = "total".freeze

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
  def add_times(name, value, accumulate = true)
    if @external_times[name] && accumulate
      @external_times[name] += value
    else
      @external_times[name] = value
    end
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
    if resources_failed_to_generate ||
       !transaction_completed ||
       (resource_metrics["failed"] || 0) > 0 ||
       (resource_metrics["failed_to_restart"] || 0) > 0
      'failed'
    elsif change_metric > 0
      'changed'
    else
      'unchanged'
    end
  end

  # @api private
  def has_noop_events?(resource)
    resource.events.any? { |event| event.status == 'noop' }
  end

  # @api private
  def prune_internal_data
    resource_statuses.delete_if {|name,res| res.resource_type == 'Whit'}
  end

  # @api private
  def finalize_report
    prune_internal_data
    calculate_report_corrective_change

    resource_metrics = add_metric(:resources, calculate_resource_metrics)
    add_metric(:time, calculate_time_metrics)
    change_metric = calculate_change_metric
    add_metric(:changes, {TOTAL => change_metric})
    add_metric(:events, calculate_event_metrics)
    @status = compute_status(resource_metrics, change_metric)
    @noop_pending = @resource_statuses.any? { |name,res| has_noop_events?(res) }
  end

  # @api private
  def initialize(configuration_version=nil, environment=nil, transaction_uuid=nil, job_id=nil)
    @metrics = {}
    @logs = []
    @resource_statuses = {}
    @external_times ||= {}
    @host = Puppet[:node_name_value]
    @time = Time.now
    @report_format = 9
    @puppet_version = Puppet.version
    @configuration_version = configuration_version
    @transaction_uuid = transaction_uuid
    @code_id = nil
    @job_id = job_id
    @catalog_uuid = nil
    @cached_catalog_status = nil
    @master_used = nil
    @environment = environment
    @status = 'failed' # assume failed until the report is finalized
    @noop = Puppet[:noop]
    @noop_pending = false
    @corrective_change = false
    @transaction_completed = false
  end

  # @api private
  def initialize_from_hash(data)
    @puppet_version = data['puppet_version']
    @report_format = data['report_format']
    @configuration_version = data['configuration_version']
    @transaction_uuid = data['transaction_uuid']
    @environment = data['environment']
    @status = data['status']
    @transaction_completed = data['transaction_completed']
    @noop = data['noop']
    @noop_pending = data['noop_pending']
    @host = data['host']
    @time = data['time']
    @corrective_change = data['corrective_change']

    if master_used = data['master_used']
      @master_used = master_used
    end

    if catalog_uuid = data['catalog_uuid']
      @catalog_uuid = catalog_uuid
    end

    if job_id = data['job_id']
      @job_id = job_id
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

    @metrics = {}
    data['metrics'].each do |name, hash|
      # Older versions contain tags that causes Psych to create instances directly
      @metrics[name] = hash.is_a?(Puppet::Util::Metric) ? hash : Puppet::Util::Metric.from_data_hash(hash)
    end

    @logs = data['logs'].map do |record|
      # Older versions contain tags that causes Psych to create instances directly
      record.is_a?(Puppet::Util::Log) ? record : Puppet::Util::Log.from_data_hash(record)
    end

    @resource_statuses = {}
    data['resource_statuses'].map do |key, rs|
      @resource_statuses[key] = if rs == Puppet::Resource::EMPTY_HASH
        nil
      else
        # Older versions contain tags that causes Psych to create instances directly
        rs.is_a?(Puppet::Resource::Status) ? rs : Puppet::Resource::Status.from_data_hash(rs)
      end
    end
  end

  def to_data_hash
    hash = {
      'host' => @host,
      'time' => @time.iso8601(9),
      'configuration_version' => @configuration_version,
      'transaction_uuid' => @transaction_uuid,
      'report_format' => @report_format,
      'puppet_version' => @puppet_version,
      'status' => @status,
      'transaction_completed' => @transaction_completed,
      'noop' => @noop,
      'noop_pending' => @noop_pending,
      'environment' => @environment,
      'logs' => @logs.map { |log| log.to_data_hash },
      'metrics' => Hash[@metrics.map { |key, metric| [key, metric.to_data_hash] }],
      'resource_statuses' => Hash[@resource_statuses.map { |key, rs| [key, rs.nil? ? nil : rs.to_data_hash] }],
      'corrective_change' => @corrective_change,
    }

    # The following is include only when set
    hash['master_used'] = @master_used unless @master_used.nil?
    hash['catalog_uuid'] = @catalog_uuid unless @catalog_uuid.nil?
    hash['code_id'] = @code_id unless @code_id.nil?
    hash['job_id'] = @job_id unless @job_id.nil?
    hash['cached_catalog_status'] = @cached_catalog_status unless @cached_catalog_status.nil?
    hash
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
        if a == TOTAL
          1
        elsif b == TOTAL
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
      report[key][TOTAL] = 0 unless key == "time" or report[key].include?(TOTAL)
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
    if @metrics["changes"] && @metrics["changes"][TOTAL] &&
        @metrics["resources"] && @metrics["resources"]["failed"] &&
        @metrics["resources"]["failed_to_restart"]
      status |= 2 if @metrics["changes"][TOTAL] > 0
      status |= 4 if @metrics["resources"]["failed"] > 0
      status |= 4 if @metrics["resources"]["failed_to_restart"] > 0
    else
      status = -1
    end
    status
  end

  private

  # Mark the report as corrective, if there are any resource_status marked corrective.
  def calculate_report_corrective_change
    @corrective_change = resource_statuses.any? do |name, status|
      status.corrective_change
    end
  end

  def calculate_change_metric
    resource_statuses.map { |name, status| status.change_count || 0 }.inject(0) { |a,b| a+b }
  end

  def calculate_event_metrics
    metrics = Hash.new(0)
    %w{total failure success}.each { |m| metrics[m] = 0 }
    resource_statuses.each do |name, status|
      metrics[TOTAL] += status.events.length
      status.events.each do |event|
        metrics[event.status] += 1
      end
    end

    metrics
  end

  def calculate_resource_metrics
    metrics = {}
    metrics[TOTAL] = resource_statuses.length

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

    metrics
  end
end
