
require 'puppet/indirector'
require 'puppet/util/instance_loader'

# Implements a message queue client type plugin registry for use by the indirector facility.
# Client modules for speaking a particular protocol (e.g. Stomp::Client for Stomp message
# brokers, Memcached for Starling and Sparrow, etc.) register themselves with this module.
#
# Client classes are expected to live under the Puppet::Util::Queue namespace and corresponding
# directory; the attempted use of a client via its typename (see below) will cause Puppet::Util::Queue
# to attempt to load the corresponding plugin if it is not yet loaded.  The client class registers itself
# with Puppet::Util::Queue and should use the same type name as the autloader expects for the plugin file.
#   class Puppet::Util::Queue::SpecialMagicalClient < Messaging::SpecialMagic
#       ...
#       Puppet::Util::Queue.register_queue_type_class(self)
#   end
#
# This module reduces the rightmost segment of the class name into a pretty symbol that will
# serve as the queuing client's name.  Which means that the "SpecialMagicalClient" above will
# be named <em>:special_magical_client</em> within the registry.
#
# Another class/module may mix-in this module, and may then make use of the registered clients.
#   class Queue::Fue
#       # mix it in at the class object level rather than instance level
#       extend ::Puppet::Util::Queue
#   end
#
# Queue::Fue instances can get a message queue client through the registry through the mixed-in method
# +client+, which will return a class-wide singleton client instance, determined by +client_class+.
#
# The client plugins are expected to implement an interface similar to that of Stomp::Client:
# * <tt>new()</tt> should return a connected, ready-to-go client instance.  Note that no arguments are passed in.
# * <tt>send_message(queue, message)</tt> should send the _message_ to the specified _queue_.
# * <tt>subscribe(queue)</tt> _block_ subscribes to _queue_ and executes _block_ upon receiving a message.
# * _queue_ names are simple names independent of the message broker or client library.  No "/queue/" prefixes like in Stomp::Client.
module Puppet::Util::Queue
    extend Puppet::Util::InstanceLoader
    instance_load :queue_clients, 'puppet/util/queue'

    # Adds a new class/queue-type pair to the registry.  The _type_ argument is optional; if not provided,
    # _type_ defaults to a lowercased, underscored symbol programmatically derived from the rightmost
    # namespace of <em>klass.name</em>.
    #
    #   # register with default name +:you+
    #   register_queue_type(Foo::You)
    #
    #   # register with explicit queue type name +:myself+
    #   register_queue_type(Foo::Me, :myself)
    #
    # If the type is already registered, an exception is thrown.  No checking is performed of _klass_,
    # however; a given class could be registered any number of times, as long as the _type_ differs with
    # each registration.
    def self.register_queue_type(klass, type = nil)
        type ||= queue_type_from_class(klass)
        raise Puppet::Error, "Queue type %s is already registered" % type.to_s if instance_hash(:queue_clients).include?(type)
        instance_hash(:queue_clients)[type] = klass
    end

    # Given a queue type symbol, returns the associated +Class+ object.  If the queue type is unknown
    # (meaning it hasn't been registered with this module), an exception is thrown.
    def self.queue_type_to_class(type)
        c = loaded_instance :queue_clients, type
        raise Puppet::Error, "Queue type %s is unknown." % type unless c
        c
    end

    # Given a class object _klass_, returns the programmatic default queue type name symbol for _klass_.
    # The algorithm is as shown in earlier examples; the last namespace segment of _klass.name_ is taken
    # and converted from mixed case to underscore-separated lowercase, and interned.
    #   queue_type_from_class(Foo) -> :foo
    #   queue_type_from_class(Foo::Too) -> :too
    #   queue_type_from_class(Foo::ForYouTwo) -> :for_you_too
    #
    # The implicit assumption here, consistent with Puppet's approach to plugins in general,
    # is that all your client modules live in the same namespace, such that reduction to
    # a flat namespace of symbols is reasonably safe.
    def self.queue_type_from_class(klass)
        # convert last segment of classname from studly caps to lower case with underscores, and symbolize
        klass.name.split('::').pop.sub(/^[A-Z]/) {|c| c.downcase}.gsub(/[A-Z]/) {|c| '_' + c.downcase }.intern
    end

    # The class object for the client to be used, determined by queue configuration
    # settings.
    # Looks to the <tt>:queue_type</tt> configuration entry in the running application for
    # the default queue type to use.
    def client_class
        Puppet::Util::Queue.queue_type_to_class(Puppet[:queue_type])
    end

    # Returns (instantiating as necessary) the singleton queue client instance, according to the
    # client_class.  No arguments go to the client class constructor, meaning its up to the client class
    # to know how to determine its queue message source (presumably through Puppet configuration data).
    def client
        @client ||= client_class.new
    end
end
