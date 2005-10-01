require 'puppet'
require 'puppet/type'

module Puppet
    # events are transient packets of information; they result in one or more (or none)
    # subscriptions getting triggered, and then they get cleared
    # eventually, these will be passed on to some central event system
	class Event
        include Puppet

        # subscriptions are permanent associations determining how different
        # objects react to an event
        class Subscription
            include Puppet
            attr_accessor :event, :callback

            # Remove the existing subscriptions and such
            def self.clear
                self.init
            end

            # Remove a subscription
            def self.delete(sub)
                type, name = sub.targetarray
                if @dependencies[type][name].include?(sub)
                    @dependencies[type][name].delete(sub)
                end

                type, name = sub.sourcearray
                if @subscriptions[type][name].include?(sub)
                    @subscriptions[type][name].delete(sub)
                end
            end

            # Initialize our class variables.  This is in a method so it can
            # be called to clear the variables, too.
            def self.init
                # A hash of subscriptions and another of dependencies, organized by
                # type, then by name.  I'm storing them all here, so that I don't
                # have to store the subscriptions with the individual objects,
                # which makes creating and destroying objects as necessary much
                # easier.
                @subscriptions = Hash.new { |hash, key|
                    hash[key] = Hash.new { |shash, skey|
                        # Each object has an array of subscriptions
                        shash[skey] = []
                    }
                }

                @dependencies = Hash.new { |hash, key|
                    hash[key] = Hash.new { |shash, skey|
                        # Each object has an array of subscriptions
                        shash[skey] = []
                    }
                }
            end

            self.init

            # Store the new subscription in a central hash.
            def self.newsub(sub)
                # The dependencies map allows me to look up a subscription by
                # target -- find out which objects a given object is subscribed
                # to, and thus find out which objects that given object depends
                # upon.
                # DEPENDENCIES == TARGET
                ttype, tname = sub.targetarray
                @dependencies[ttype][tname] << sub

                # Subscriptions are the list of subscriptions for a given object,
                # i.e., the list of all objects that care about a given object's
                # events.
                # SUBSCRIPTION == SOURCE
                stype, sname = sub.sourcearray
                @subscriptions[stype][sname] << sub
            end

            # Trigger the subscriptions related to an event, and then pass it up
            # as appropriate
            def self.trigger(source, event, transaction)
                type, name = self.split(source)

                @subscriptions[type][name].each { |sub|
                    if sub.match?(event)
                        sub.trigger(transaction)
                    end
                }
            end

            # Look up an object by type and name.  This is used because we
            # store symbolic links in our subscription hash rather than storing
            # actual object references.
            def self.retrieve(ary)
                type, name = ary
                typeobj = Puppet::Type.type(type)

                unless typeobj
                    return nil
                end

                obj = typeobj[name]
                return obj
            end

            # Split an object into its type and name
            def self.split(object)
                return [object.class.name, object.name]
            end

            # Retrieve all of the subscriptions that result in a dependency.
            # We return the whole dependency here, because it is being returned
            # to the object that made the subscription.
            def self.dependencies(target)
                type, name = self.split(target)
                return @dependencies[type][name]
            end

            # Return all objects that are subscribed to us.  We are only willing
            # to return the object, not the subscription object, because the
            # source shouldn't need to know things like the event or method that
            # we're subscribed to.
            def self.subscribers(source)
                type, name = self.split(source)
                return @subscriptions[type][name].collect { |sub|
                    sub.target
                }
            end

            # The hash here must include the target and source objects, the event,
            # and the callback to call.
            def initialize(hash)
                hash.each { |param,value|
                    # assign each value appropriately
                    # this is probably wicked-slow
                    self.send(param.to_s + "=",value)
                }

                self.class.newsub(self)
                #Puppet.debug "New Subscription: '%s' => '%s'" %
                #    [@source,@event]
            end

            # Determine whether the passed event matches our event
            def match?(event)
                if event == :NONE or @event == :NONE
                    return false
                elsif @event == :ALL_EVENTS or event == :ALL_EVENTS or event == @event
                    return true
                else
                    return false
                end
            end

            # The source is the event source.
            def source=(object)
                type, name = self.class.split(object)
                @source = [type, name]
            end

            def source
                self.class.retrieve(@source)
            end

            def sourcearray
                @source
            end

            # The target is the object who will receive the callbacks, i.e.,
            # a source generates an event, which results in a callback on the
            # target.
            def target=(object)
                type, name = self.class.split(object)
                @target = [type, name]
            end

            def target
                self.class.retrieve(@target)
            end

            def targetarray
                @target
            end

            # Trigger a subscription, which basically calls the associated method
            # on the target object.
            def trigger(transaction)
                event = nil

                if @event == :NONE
                    # just ignore these subscriptions
                    return
                end

                if transaction.triggered?(self.target, @callback) > 0
                    Puppet.debug "%s has already run" % self
                else
                    # We need to call the method, so that it gets retrieved
                    # as a real object.
                    target = self.target
                    #Puppet.debug "'%s' matched '%s'; triggering '%s' on '%s'" %
                    #    [@source,@event,@method,target]
                    begin
                        if target.respond_to?(@callback)
                            event = target.send(@callback)
                        else
                            Puppet.debug(   
                                "'%s' of type '%s' does not respond to '%s'" %
                                [target,target.class,@callback.inspect]
                            )
                        end
                    rescue => detail
                        # um, what the heck do i do when an object fails to
                        # refresh?  shouldn't that result in the transaction
                        # rolling back?  the 'onerror' metaparam will be used
                        # to determine behaviour in that case
                        Puppet.err "'%s' failed to %s: '%s'" %
                            [target,@callback,detail]
                        raise
                        #raise "We need to roll '%s' transaction back" %
                            #transaction
                    end
                    transaction.triggered(target, @callback)
                end
                return event
            end
        end

		attr_accessor :event, :source, :transaction

        @@events = []

        @@subscriptions = []

		def initialize(args)
            unless args.include?(:event) and args.include?(:source)
				raise Puppet::DevError, "Event.new called incorrectly"
			end

			@change = args[:change]
			@event = args[:event]
			@source = args[:source]
			@transaction = args[:transaction]

            #Puppet.info "%s: %s(%s)" %
            #Puppet.info "%s: %s changed from %s to %s" %
            #    [@object,@state.name, @state.is,@state.should]

            # initially, just stuff all instances into a central bucket
            # to be handled as a batch
            #@@events.push self
		end

        def to_s
            self.event.to_s
        end
	end
end

# $Id$
