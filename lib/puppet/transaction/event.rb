require 'puppet'
require 'puppet/util/methodhelper'
require 'puppet/util/errors'

# events are transient packets of information; they result in one or more (or none)
# subscriptions getting triggered, and then they get cleared
# eventually, these will be passed on to some central event system
class Puppet::Transaction::Event
    include Puppet::Util::MethodHelper
    include Puppet::Util::Errors
    
    attr_accessor :event, :source, :transaction

    def initialize(args)
        set_options symbolize_options(args)
        requiredopts(:event, :source)
    end

    def to_s
        @source.to_s + " -> " + self.event.to_s
    end
end
