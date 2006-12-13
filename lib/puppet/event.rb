require 'puppet'
require 'puppet/type'

module Puppet
    # events are transient packets of information; they result in one or more (or none)
    # subscriptions getting triggered, and then they get cleared
    # eventually, these will be passed on to some central event system
	class Event
        include Puppet
		attr_accessor :event, :source, :transaction

        @@events = []

		def initialize(args)
            unless args.include?(:event) and args.include?(:source)
				raise Puppet::DevError, "Event.new called incorrectly"
			end

			@change = args[:change]
			@event = args[:event]
			@source = args[:source]
			@transaction = args[:transaction]
		end

        def to_s
            @source.to_s + " -> " + self.event.to_s
        end
	end
end

# $Id$
