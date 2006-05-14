require 'puppet/rails'

class Puppet::Parser::AST
    # An object that collects stored objects from the central cache and returns
    # them to the current host, yo.
    class Collection < AST::Branch
        attr_accessor :type

        def evaluate(hash)
            scope = hash[:scope]

            type = @type.safeevaluate(:scope => scope)

            count = 0
            # Now perform the actual collection, yo.

            # First get everything from the export table.
            
            # FIXME This will only find objects that are before us in the tree,
            # which is a problem.
            objects = scope.exported(type)

            array = objects.values

            Puppet::Rails::RailsObject.find_all_by_collectable(true).each do |obj|
                if objects.include?(obj.name)
                    debug("%s[%s] is already exported" % [type, obj.name])
                    next
                end
                count += 1
                trans = obj.to_trans

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
                [count, type])

            # The return value is entirely ignored right now, unfortunately.
            return nil
        end
    end
end

# $Id$
