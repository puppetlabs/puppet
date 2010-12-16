require 'puppet/transaction'
require 'puppet/transaction/event'

# Handle all of the work around performing an actual change,
# including calling 'sync' on the properties and producing events.
class Puppet::Transaction::Change
  attr_accessor :is, :should, :property, :proxy, :auditing, :old_audit_value

  def auditing?
    auditing
  end

  def initialize(property, currentvalue)
    @property = property
    @is = currentvalue

    @should = property.should

    @changed = false
  end

  def apply
    event = property.event
    event.previous_value = is
    event.desired_value = should
    event.historical_value = old_audit_value

    if auditing? and old_audit_value != is
      event.message = "audit change: previously recorded value #{property.is_to_s(old_audit_value)} has been changed to #{property.is_to_s(is)}"
      event.status = "audit"
      event.audited = true
      brief_audit_message = " (previously recorded value was #{property.is_to_s(old_audit_value)})" 
    else
      brief_audit_message = "" 
    end

    if property.insync?(is)
      # nothing happens
    elsif noop?
      event.message = "is #{property.is_to_s(is)}, should be #{property.should_to_s(should)} (noop)#{brief_audit_message}"
      event.status = "noop"
    else
      property.sync
      event.message = [ property.change_to_s(is, should), brief_audit_message ].join
      event.status = "success"
    end
    event
  rescue => detail
    puts detail.backtrace if Puppet[:trace]
    event.status = "failure"

    event.message = "change from #{property.is_to_s(is)} to #{property.should_to_s(should)} failed: #{detail}"
    event
  ensure
    event.send_log
  end

  # Is our property noop?  This is used for generating special events.
  def noop?
    @property.noop
  end

  # The resource that generated this change.  This is used for handling events,
  # and the proxy resource is used for generated resources, since we can't
  # send an event to a resource we don't have a direct relationship with.  If we
  # have a proxy resource, then the events will be considered to be from
  # that resource, rather than us, so the graph resolution will still work.
  def resource
    self.proxy || @property.resource
  end

  def to_s
    "change #{@property.change_to_s(@is, @should)}"
  end
end
