require 'puppet'
require 'puppet/util/methodhelper'
require 'puppet/util/errors'

module Puppet
    # events are transient packets of information; they result in one or more (or none)
    # subscriptions getting triggered, and then they get cleared
    # eventually, these will be passed on to some central event system
	class Event
        include Puppet
        include Puppet::Util::MethodHelper
        include Puppet::Util::Errors
        
		attr_accessor :event, :source, :transaction

        @@events = []

		def initialize(args)
		    set_options symbolize_options(args)
		    requiredopts(:event, :source)
		end

        def to_s
            @source.to_s + " -> " + self.event.to_s
        end
	end
end

