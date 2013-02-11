require 'puppet/transaction'
require 'puppet/util/tagging'
require 'puppet/util/logging'
require 'puppet/util/methodhelper'

# A simple struct for storing what happens on the system.
class Puppet::Transaction::Event
  include Puppet::Util::MethodHelper
  include Puppet::Util::Tagging
  include Puppet::Util::Logging

  ATTRIBUTES = [:name, :resource, :property, :previous_value, :desired_value, :historical_value, :status, :message, :file, :line, :source_description, :audited, :invalidate_refreshes]
  YAML_ATTRIBUTES = %w{@audited @property @previous_value @desired_value @historical_value @message @name @status @time}.map(&:to_sym)
  attr_accessor *ATTRIBUTES
  attr_writer :tags
  attr_accessor :time
  attr_reader :default_log_level

  EVENT_STATUSES = %w{noop success failure audit}

  def initialize(options = {})
    @audited = false
    set_options(options)
    @time = Time.now
  end

  def property=(prop)
    @property = prop.to_s
  end

  def resource=(res)
    if res.respond_to?(:[]) and level = res[:loglevel]
      @default_log_level = level
    end
    @resource = res.to_s
  end

  def send_log
    super(log_level, message)
  end

  def status=(value)
    raise ArgumentError, "Event status can only be #{EVENT_STATUSES.join(', ')}" unless EVENT_STATUSES.include?(value)
    @status = value
  end

  def to_s
    message
  end

  def to_yaml_properties
    YAML_ATTRIBUTES & instance_variables
  end

  private

  # If it's a failure, use 'err', else use either the resource's log level (if available)
  # or 'notice'.
  def log_level
    status == "failure" ? :err : (@default_log_level || :notice)
  end

  # Used by the Logging module
  def log_source
    source_description || property || resource
  end
end
