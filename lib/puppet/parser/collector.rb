# An object that collects stored objects from the central cache and returns
# them to the current host, yo.
class Puppet::Parser::Collector
    attr_accessor :type, :scope, :vquery, :equery, :form, :resources, :overrides, :collected

    # Call the collection method, mark all of the returned objects as non-virtual,
    # optionally applying parameter overrides. The collector can also delete himself
    # from the compiler if there is no more resources to collect (valid only for resource fixed-set collector
    # which get their resources from +collect_resources+ and not from the catalog)
    def evaluate
        # Shortcut if we're not using storeconfigs and they're trying to collect
        # exported resources.
        if form == :exported and Puppet[:storeconfigs] != true
            Puppet.warning "Not collecting exported resources without storeconfigs"
            return false
        end

        if self.resources
            unless objects = collect_resources and ! objects.empty?
                return false
            end
        else
            method = "collect_#{@form.to_s}"
            objects = send(method).each do |obj|
                obj.virtual = false
            end
            if objects.empty?
                return false
            end
        end

        # we have an override for the collected resources
        if @overrides and !objects.empty?

            # force the resource to be always child of any other resource
            overrides[:source].meta_def(:child_of?) do
                true
            end

            # tell the compiler we have some override for him unless we already
            # overrided those resources
            objects.each do |res|
                unless @collected.include?(res.ref)
                    res = Puppet::Parser::Resource.new(
                        :type => res.type,
                        :title => res.title,
                        :params => overrides[:params],
                        :file => overrides[:file],
                        :line => overrides[:line],
                        :source => overrides[:source],
                        :scope => overrides[:scope]
                    )

                    scope.compiler.add_override(res)
                end
            end
        end

        # filter out object that already have been collected by ourself
        objects.reject! { |o| @collected.include?(o.ref) }

        return false if objects.empty?

        # keep an eye on the resources we have collected
        objects.inject(@collected) { |c,o| c[o.ref]=o; c }

        # return our newly collected resources
        objects
    end

    def initialize(scope, type, equery, vquery, form)
        @scope = scope

        # initialisation
        @collected = {}

        # Canonize the type
        @type = Puppet::Resource::Reference.new(type, "whatever").type
        @equery = equery
        @vquery = vquery

        raise(ArgumentError, "Invalid query form %s" % form) unless [:exported, :virtual].include?(form)
        @form = form
    end

    # add a resource override to the soon to be exported/realized resources
    def add_override(hash)
        unless hash[:params]
            raise ArgumentError, "Exported resource try to override without parameters"
        end

        # schedule an override for an upcoming collection
        @overrides = hash
    end

    private

    # Create our active record query.
    def build_active_record_query
        Puppet::Rails.init unless ActiveRecord::Base.connected?

        raise Puppet::DevError, "Cannot collect resources for a nil host" unless @scope.host
        host = Puppet::Rails::Host.find_by_name(@scope.host)

        search = "(exported=? AND restype=?)"
        values = [true, @type]

        search += " AND (%s)" % @equery if @equery

        # note:
        # we're not eagerly including any relations here because
        # it can creates so much objects we'll throw out later.
        # We used to eagerly include param_names/values but the way
        # the search filter is built ruined those efforts and we
        # were eagerly loading only the searched parameter and not
        # the other ones. 
        query = {}
        case search
        when /puppet_tags/
            query = {:joins => {:resource_tags => :puppet_tag}}
        when /param_name/
            query = {:joins => {:param_values => :param_name}}
        end

        # We're going to collect objects from rails, but we don't want any
        # objects from this host.
        search = ("host_id != ? AND %s" % search) and values.unshift(host.id) if host

        query[:conditions] = [search, *values]

        return query
    end

    # Collect exported objects.
    def collect_exported
        # First get everything from the export table.  Just reuse our
        # collect_virtual method but tell it to use 'exported? for the test.
        resources = collect_virtual(true).reject { |r| ! r.virtual? }

        count = resources.length

        query = build_active_record_query

        # Now look them up in the rails db.  When we support attribute comparison
        # and such, we'll need to vary the conditions, but this works with no
        # attributes, anyway.
        time = Puppet::Util.thinmark do
            Puppet::Rails::Resource.find(:all, query).each do |obj|
                if resource = exported_resource(obj)
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
        raise Puppet::ParseError, "realize() is not yet implemented for exported resources"
    end

    # Collect resources directly; this is the result of using 'realize',
    # which specifies resources, rather than using a normal collection.
    def collect_virtual_resources
        return [] unless defined?(@resources) and ! @resources.empty?
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
            @scope.compiler.delete_collection(self)
        end

        return result
    end

    # Collect just virtual objects, from our local compiler.
    def collect_virtual(exported = false)
        scope.compiler.resources.find_all do |resource|
            resource.type == @type and (exported ? resource.exported? : true) and match?(resource)
        end
    end

    # Seek a specific exported resource.
    def exported_resource(obj)
        if existing = @scope.findresource(obj.restype, obj.title)
            # Next see if we've already collected this resource
            return nil if existing.rails_id == obj.id

            # This is the one we've already collected
            raise Puppet::ParseError, "Exported resource %s cannot override local resource" % [obj.ref]
        end

        resource = obj.to_resource(self.scope)

        resource.exported = false

        scope.compiler.add_resource(scope, resource)

        return resource
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
