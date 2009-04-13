require 'puppet/util/queue'
require 'stomp'

# Implements the Ruby Stomp client as a queue type within the Puppet::Indirector::Queue::Client
# registry, for use with the <tt>:queue</tt> indirection terminus type.
#
# Looks to <tt>Puppet[:queue_source]</tt> for the sole argument to the underlying Stomp::Client constructor;
# consequently, for this client to work, <tt>Puppet[:queue_source]</tt> must use the Stomp::Client URL-like
# syntax for identifying the Stomp message broker: <em>login:pass@host.port</em>
class Puppet::Util::Queue::Stomp
    attr_accessor :stomp_client

    def initialize
        self.stomp_client = Stomp::Client.new( Puppet[:queue_source] )
    end

    def send_message(target, msg)
        stomp_client.send(stompify_target(target), msg)
    end

    def subscribe(target)
        stomp_client.subscribe(stompify_target(target)) {|stomp_message| yield(stomp_message.body)}
    end

    def stompify_target(target)
        '/queue/' + target.to_s
    end

    Puppet::Util::Queue.register_queue_type(self, :stomp)
end
