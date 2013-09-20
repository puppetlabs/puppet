require 'puppet/transaction'

class Puppet::Transaction::EventManager
  attr_reader :transaction, :events

  def initialize(transaction)
    @transaction = transaction
    @event_queues = {}
    @events = []
  end

  def relationship_graph
    transaction.relationship_graph
  end

  # Respond to any queued events for this resource.
  def process_events(resource)
    restarted = false
    queued_events(resource) do |callback, events|
      r = process_callback(resource, callback, events)
      restarted ||= r
    end

    if restarted
      queue_events(resource, [resource.event(:name => :restarted, :status => "success")])

      transaction.resource_status(resource).restarted = true
    end
  end

  # Queue events for other resources to respond to.  All of these events have
  # to be from the same resource.
  def queue_events(resource, events)
    #@events += events

    # Do some basic normalization so we're not doing so many
    # graph queries for large sets of events.
    events.inject({}) do |collection, event|
      collection[event.name] ||= []
      collection[event.name] << event
      collection
    end.collect do |name, list|
      # It doesn't matter which event we use - they all have the same source
      # and name here.
      event = list[0]

      # Collect the targets of any subscriptions to those events.  We pass
      # the parent resource in so it will override the source in the events,
      # since eval_generated children can't have direct relationships.
      received = (event.name != :restarted)
      relationship_graph.matching_edges(event, resource).each do |edge|
        received ||= true unless edge.target.is_a?(Puppet::Type.type(:whit))
        next unless method = edge.callback
        next unless edge.target.respond_to?(method)

        queue_events_for_resource(resource, edge.target, method, list)
      end
      @events << event if received

      queue_events_for_resource(resource, resource, :refresh, [event]) if resource.self_refresh? and ! resource.deleting?
    end

    dequeue_events_for_resource(resource, :refresh) if events.detect { |e| e.invalidate_refreshes }
  end

  def dequeue_events_for_resource(target, callback)
    target.info "Unscheduling #{callback} on #{target}"
    @event_queues[target][callback] = {} if @event_queues[target]
  end

  def queue_events_for_resource(source, target, callback, events)
    whit = Puppet::Type.type(:whit)

    # The message that a resource is refreshing the completed-whit for its own class
    # is extremely counter-intuitive. Basically everything else is easy to understand,
    # if you suppress the whit-lookingness of the whit resources
    refreshing_c_whit = target.is_a?(whit) && target.name =~ /^completed_/

    if refreshing_c_whit
      source.debug "The container #{target} will propagate my #{callback} event"
    else
      source.info "Scheduling #{callback} of #{target}"
    end

    @event_queues[target] ||= {}
    @event_queues[target][callback] ||= []
    @event_queues[target][callback].concat(events)
  end

  def queued_events(resource)
    return unless callbacks = @event_queues[resource]
    callbacks.each do |callback, events|
      yield callback, events unless events.empty?
    end
  end

  private

  def process_callback(resource, callback, events)
    process_noop_events(resource, callback, events) and return false unless events.detect { |e| e.status != "noop" }
    resource.send(callback)

    if not resource.is_a?(Puppet::Type.type(:whit))
      resource.notice "Triggered '#{callback}' from #{events.length} events"
    end
    return true
  rescue => detail
    resource.err "Failed to call #{callback}: #{detail}"

    transaction.resource_status(resource).failed_to_restart = true
    resource.log_exception(detail)
    return false
  end

  def process_noop_events(resource, callback, events)
    resource.notice "Would have triggered '#{callback}' from #{events.length} events"

    # And then add an event for it.
    queue_events(resource, [resource.event(:status => "noop", :name => :noop_restart)])
    true # so the 'and if' works
  end
end
