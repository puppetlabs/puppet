require 'puppet/rails'

class Puppet::Parser::AST
    # An object that collects stored objects from the central cache and returns
    # them to the current host, yo.
    class Collection < AST::Branch
        attr_accessor :type

        # We cannot evaluate directly here; instead we need to store a 
        # CollectType object, which will do the collection.  This is
        # the only way to find certain exported types in the current
        # configuration.
        def evaluate(hash)
            scope = hash[:scope]

            @convertedtype = @type.safeevaluate(:scope => scope)

            scope.newcollection(self)
        end

        # Now perform the actual collection, yo.
        def perform(scope)
            # First get everything from the export table.
            
            # FIXME This will only find objects that are before us in the tree,
            # which is a problem.
            objects = scope.exported(@convertedtype)

            # We want to return all of these objects, and then whichever objects
            # we find in the db.
            array = objects.values

            # Mark all of these objects as collected, so that they also get
            # returned to the client.  We don't store them in our scope
            # or anything, which is a little odd, but eh.
            array.each do |obj|
                obj.collected = true
            end

            count = array.length

            # Now we also have to see if there are any exported objects
            # in our own scope.
            scope.lookupexported(@convertedtype).each do |obj|
                objects[obj.name] = obj
                obj.collected = true
            end

            bucket = Puppet::TransBucket.new

            Puppet::Rails::RailsObject.find_all_by_collectable(true).each do |obj|
                # FIXME This should check that the source of the object is the
                # host we're running on, else it's a bad conflict.
                if objects.include?(obj.name)
                    scope.debug("%s[%s] is already exported" % [@convertedtype, obj.name])
                    next
                end
                count += 1
                trans = obj.to_trans
                bucket.push(trans)

                args = {
                    :name => trans.name,
                    :type => trans.type,
                }

                [:file, :line].each do |param|
                    if val = trans.send(param)
                        args[param] = val
                    end
                end

                args[:arguments] = {}
                trans.each do |p,v|  args[:arguments][p] = v end

                
                # XXX Because the scopes don't expect objects to return values,
                # we have to manually add our objects to the scope.  This is
                # uber-lame.
                scope.setobject(args)
            end

            scope.debug("Collected %s objects of type %s" %
                [count, @convertedtype])

            return bucket
        end
    end
end

# $Id$
