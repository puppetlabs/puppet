# frozen_string_literal: true

require_relative '../../puppet/transaction'
require_relative '../../puppet/util/tagging'
require_relative '../../puppet/util/logging'
require_relative '../../puppet/network/format_support'

# A simple struct for storing what happens on the system.
class Puppet::Transaction::Event
  include Puppet::Util::Tagging
  include Puppet::Util::Logging
  include Puppet::Network::FormatSupport

  ATTRIBUTES = [:name, :resource, :property, :previous_value, :desired_value, :historical_value, :status, :message, :file, :line, :source_description, :audited, :invalidate_refreshes, :redacted, :corrective_change]
  attr_accessor(*ATTRIBUTES)
  attr_accessor :time
  attr_reader :default_log_level

  EVENT_STATUSES = %w[noop success failure audit]

  def self.from_data_hash(data)
    obj = self.allocate
    obj.initialize_from_hash(data)
    obj
  end

  def initialize(audited: false,
                 corrective_change: false,
                 desired_value: nil,
                 file: nil,
                 historical_value: nil,
                 invalidate_refreshes: nil,
                 line: nil,
                 message: nil,
                 name: nil,
                 previous_value: nil,
                 property: nil,
                 redacted: false,
                 resource: nil,
                 source_description: nil,
                 status: nil,
                 tags: nil)

    @audited = audited
    @corrective_change = corrective_change
    @desired_value = desired_value
    @file = file
    @historical_value = historical_value
    @invalidate_refreshes = invalidate_refreshes
    @line = line
    @message = message
    @name = name
    @previous_value = previous_value
    @redacted = redacted
    @source_description = source_description
    @tags = tags

    self.property = property if property
    self.resource = resource if resource
    self.status = status if status

    @time = Time.now
  end

  def eql?(event)
    self.class == event.class && ATTRIBUTES.all? { |attr| send(attr).eql?(event.send(attr)) }
  end
  alias == eql?

  def initialize_from_hash(data)
    data = Puppet::Pops::Serialization::FromDataConverter.convert(data, {
                                                                    :allow_unresolved => true,
                                                                    :loader => Puppet::Pops::Loaders.static_loader
                                                                  })
    @audited = data['audited']
    @property = data['property']
    @previous_value = data['previous_value']
    @desired_value = data['desired_value']
    @historical_value = data['historical_value']
    @message = data['message']
    @name = data['name'].intern if data['name']
    @status = data['status']
    @time = data['time']
    @time = Time.parse(@time) if @time.is_a? String
    @redacted = data.fetch('redacted', false)
    @corrective_change = data['corrective_change']
  end

  def to_data_hash
    hash = {
      'audited' => @audited,
      'property' => @property,
      'previous_value' => @previous_value,
      'desired_value' => @desired_value,
      'historical_value' => @historical_value,
      'message' => @message,
      'name' => @name.nil? ? nil : @name.to_s,
      'status' => @status,
      'time' => @time.iso8601(9),
      'redacted' => @redacted,
      'corrective_change' => @corrective_change,
    }
    # Use the stringifying converter since rich data is not possible downstream.
    # (This will destroy some data type information, but this is expected).
    Puppet::Pops::Serialization::ToStringifiedConverter.convert(hash, :message_prefix => 'Event')
  end

  def property=(prop)
    @property_instance = prop
    @property = prop.to_s
  end

  def resource=(res)
    level = res[:loglevel] if res.respond_to?(:[])
    if level
      @default_log_level = level
    end
    @resource = res.to_s
  end

  def send_log
    super(log_level, message)
  end

  def status=(value)
    raise ArgumentError, _("Event status can only be %{statuses}") % { statuses: EVENT_STATUSES.join(', ') } unless EVENT_STATUSES.include?(value)

    @status = value
  end

  def to_s
    message
  end

  def inspect
    %Q(#<#{self.class.name} @name="#{@name.inspect}" @message="#{@message.inspect}">)
  end

  # Calculate and set the corrective_change parameter, based on the old_system_value of the property.
  # @param [Object] old_system_value system_value from last transaction
  # @return [bool] true if this is a corrective_change
  def calculate_corrective_change(old_system_value)
    # Only idempotent properties, and cases where we have an old system_value
    # are corrective_changes.
    if @property_instance.idempotent? &&
       !@property_instance.sensitive &&
       !old_system_value.nil?

      # If the values aren't insync, we have confirmed a corrective_change
      insync = @property_instance.insync_values?(old_system_value, previous_value)

      # Preserve the nil state, but flip true/false
      @corrective_change = insync.nil? ? nil : !insync
    else
      @corrective_change = false
    end
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
