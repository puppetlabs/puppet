# An object that collects stored objects from the central cache and returns
# them to the current host, yo.
class Puppet::Parser::Collector
    attr_accessor :type, :scope, :vquery, :rquery, :form

    # Collect exported objects.
    def collect_exported
        require 'puppet/rails'
        # First get everything from the export table.  Just reuse our
        # collect_virtual method but tell it to use 'exported? for the test.
        resources = collect_virtual(true)

        count = resources.length

        # We're going to collect objects from rails, but we don't want any
        # objects from this host.
        host = Puppet::Rails::Host.find_by_name(@scope.host)

        args = {}
        if host
            args[:conditions] = "host_id != #{host.id}"
        else
            #Puppet.info "Host %s is uninitialized" % @scope.host
        end

        # Now look them up in the rails db.  When we support attribute comparison
        # and such, we'll need to vary the conditions, but this works with no
        # attributes, anyway.
        Puppet::Util.benchmark(:debug, "Collected #{self.type} resources") do
            Puppet::Rails::RailsResource.find_all_by_restype_and_exported(@type, true,
                args
            ).each do |obj|
                count += 1
                resource = obj.to_resource(self.scope)
                
                # XXX Because the scopes don't expect objects to return values,
                # we have to manually add our objects to the scope.  This is
                # uber-lame.
                scope.setresource(resource)

                resources << resource
            end
        end

        scope.debug("Collected %s objects of type %s" %
            [count, @convertedtype])

        return resources
    end

    # Collect just virtual objects, from our local configuration.
    def collect_virtual(exported = false)
        if exported
            method = :exported?
        else
            method = :virtual?
        end
        scope.resources.find_all do |resource|
            resource.type == @type and resource.send(method) and match?(resource)
        end
    end

    # Call the collection method, mark all of the returned objects as non-virtual,
    # and then delete this object from the list of collections to evaluate.
    def evaluate
        method = "collect_#{@form.to_s}"
        objects = send(method).each do |obj|
            obj.virtual = false
        end

        # And then remove us from the list of collections, since we've
        # now been evaluated.
        @scope.collections.delete(self)

        objects
    end

    def initialize(scope, type, equery, vquery, form)
        @scope = scope
        @type = type
        @equery = equery
        @vquery = vquery
        @form = form
        @tests = []
    end

    # Does the resource match our tests?  We don't yet support tests,
    # so it's always true at the moment.
    def match?(resource)
        if self.vquery
            return self.vquery.call(resource)
        else
            return true
        end
    end
end

# $Id$
