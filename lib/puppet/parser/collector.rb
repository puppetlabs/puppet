# An object that collects stored objects from the central cache and returns
# them to the current host, yo.
class Puppet::Parser::Collector
    attr_accessor :type, :scope, :vquery, :rquery, :form, :resources

    # Collect exported objects.
    def collect_exported
        # First get everything from the export table.  Just reuse our
        # collect_virtual method but tell it to use 'exported? for the test.
        resources = collect_virtual(true).reject { |r| ! r.virtual? }

        count = 0

        unless @scope.host
            raise Puppet::DevError, "Cannot collect resources for a nil host"
        end

        # We're going to collect objects from rails, but we don't want any
        # objects from this host.
        unless ActiveRecord::Base.connected?
            Puppet::Rails.init
        end
        host = Puppet::Rails::Host.find_by_name(@scope.host)

        args = {:include => {:param_values => :param_name}}
        args[:conditions] = "(exported = %s AND restype = '%s')" %
	    [ActiveRecord::Base.connection.quote(true), @type]
        if @equery
            args[:conditions] += " AND (%s)" % [@equery]
        end
        if host
            args[:conditions] = "host_id != %s AND %s" % [host.id, args[:conditions]]
        else
            #Puppet.info "Host %s is uninitialized" % @scope.host
        end

        # Now look them up in the rails db.  When we support attribute comparison
        # and such, we'll need to vary the conditions, but this works with no
        # attributes, anyway.
        time = Puppet::Util.thinmark do
            Puppet::Rails::Resource.find(:all, @type, true,
                args
            ).each do |obj|
                if resource = export_resource(obj)
                    count += 1
                    resources << resource
                end
            end
        end

        scope.debug("Collected %s %s resource%s in %.2f seconds" %
            [count, @type, count == 1 ? "" : "s", time])

        return resources
    end

    def collect_resources
        unless @resources.is_a?(Array)
            @resources = [@resources]
        end
        method = "collect_#{form.to_s}_resources"
        send(method)
    end

    def collect_exported_resources
        raise Puppet::ParseError,
            "realize() is not yet implemented for exported resources"
    end

    # Collect resources directly; this is the result of using 'realize',
    # which specifies resources, rather than using a normal collection.
    def collect_virtual_resources
        result = @resources.dup.collect do |ref|
            if res = @scope.findresource(ref.to_s)
                @resources.delete(ref)
                res
            end
        end.reject { |r| r.nil? }.each do |res|
            res.virtual = false
        end

        # If there are no more resources to find, delete this from the list
        # of collections.
        if @resources.empty?
            @scope.compile.delete_collection(self)
        end

        return result
    end

    # Collect just virtual objects, from our local compile.
    def collect_virtual(exported = false)
        if exported
            method = :exported?
        else
            method = :virtual?
        end
        scope.compile.resources.find_all do |resource|
            resource.type == @type and resource.send(method) and match?(resource)
        end
    end

    # Call the collection method, mark all of the returned objects as non-virtual,
    # and then delete this object from the list of collections to evaluate.
    def evaluate
        if self.resources
            if objects = collect_resources and ! objects.empty?
                return objects
            else
                return false
            end
        else
            method = "collect_#{@form.to_s}"
            objects = send(method).each { |obj| obj.virtual = false }
            if objects.empty?
                return false
            else
                return objects
            end
        end
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

    def export_resource(obj)
        if existing = @scope.findresource(obj.restype, obj.title)
            # See if we exported it; if so, just move on
            if @scope.host == obj.host.name
                return nil
            else
                # Next see if we've already collected this resource
                if existing.rails_id == obj.id
                    # This is the one we've already collected
                    return nil
                else
                    raise Puppet::ParseError,
                        "Exported resource %s cannot override local resource" %
                        [obj.ref]
                end
            end
        end

        begin
            resource = obj.to_resource(self.scope)
            
            # XXX Because the scopes don't expect objects to return values,
            # we have to manually add our objects to the scope.  This is
            # über-lame.
            scope.compile.store_resource(scope, resource)
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            raise
        end
        resource.exported = false

        return resource
    end
end
