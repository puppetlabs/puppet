module Puppet::Util::CollectionMerger
    # Merge new values with the old list.  This is only necessary
    # because deletion seems to mess things up on unsaved objects.
    def collection_merge(collection, args)
        remove = []
        list = args[:existing] || send(collection)
        hash = args[:updates]
        list.each do |object|
            name = object.name
            if existing = hash[name]
                hash.delete(name)
                if existing.respond_to?(:to_rails)
                    existing.to_rails(self, object)
                elsif args.include?(:modify)
                    args[:modify].call(object, name, existing)
                else
                    raise ArgumentError, "Must pass :modify or the new objects must respond to :to_rails"
                end
            else
                remove << object
            end
        end

        # Make a new rails object for the rest of them
        hash.each do |name, object|
            if object.respond_to?(:to_rails)
                object.to_rails(self)
            elsif args.include?(:create)
                args[:create].call(name, object)
            else
                raise ArgumentError, "Must pass :create or the new objects must respond to :to_rails"
            end
        end

        # Now remove anything necessary.
        remove.each do |object|
            send(collection).delete(object)
        end
    end
end

# $Id$
