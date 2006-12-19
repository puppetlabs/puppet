module Puppet::Util::CollectionMerger
    # Merge new values with the old list.  This is only necessary
    # because deletion seems to mess things up on unsaved objects.
    def collection_merge(collection, list)
        remove = send(collection).dup

        list.each do |value|
            object = yield(value)
            if remove.include?(object)
                remove.delete(object)
            end
        end

        unless remove.empty?
            # We have to save the current state else the deletion somehow deletes
            # our new values.
            save
            remove.each do |r|
                send(collection).delete(r)
            end
        end
    end
end

# $Id$
