# An object that collects stored objects from the central cache and returns
# them to the current host, yo.
class Puppet::Parser::Collector
  attr_accessor :type, :scope, :vquery, :equery, :form
  attr_accessor :resources, :overrides, :collected

  # Call the collection method, mark all of the returned objects as
  # non-virtual, optionally applying parameter overrides. The collector can
  # also delete himself from the compiler if there is no more resources to
  # collect (valid only for resource fixed-set collector which get their
  # resources from +collect_resources+ and not from the catalog)
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
      return false if objects.empty?
    end

    # we have an override for the collected resources
    if @overrides and !objects.empty?
      # force the resource to be always child of any other resource
      overrides[:source].meta_def(:child_of?) do |klass|
        true
      end

      # tell the compiler we have some override for him unless we already
      # overrided those resources
      objects.each do |res|
        unless @collected.include?(res.ref)
          newres = Puppet::Parser::Resource.
            new(res.type, res.title,
                :parameters => overrides[:parameters],
                :file       => overrides[:file],
                :line       => overrides[:line],
                :source     => overrides[:source],
                :scope      => overrides[:scope])

          scope.compiler.add_override(newres)
        end
      end
    end

    # filter out object that this collector has previously found.
    objects.reject! { |o| @collected.include?(o.ref) }

    return false if objects.empty?

    # keep an eye on the resources we have collected
    objects.inject(@collected) { |c,o| c[o.ref]=o; c }

    # return our newly collected resources
    objects
  end

  def initialize(scope, type, equery, vquery, form)
    @scope  = scope
    @vquery = vquery
    @equery = equery

    # initialisation
    @collected = {}

    # Canonize the type
    @type = Puppet::Resource.new(type, "whatever").type

    unless [:exported, :virtual].include?(form)
      raise ArgumentError, "Invalid query form #{form}"
    end
    @form = form
  end

  # add a resource override to the soon to be exported/realized resources
  def add_override(hash)
    raise ArgumentError, "Exported resource try to override without parameters" unless hash[:parameters]

    # schedule an override for an upcoming collection
    @overrides = hash
  end

  private

  # Collect exported objects.
  def collect_exported
    resources = []

    time = Puppet::Util.thinmark do
      # First get everything from the export table.  Just reuse our
      # collect_virtual method but tell it to use 'exported? for the test.
      resources = collect_virtual(true).reject { |r| ! r.virtual? }

      # key is '#{type}/#{name}', and host and filter.
      found = Puppet::Resource.indirection.
        search(@type, :host => @scope.compiler.node.name, :filter => @equery, :scope => @scope)

      found_resources = found.map {|x| x.is_a?(Puppet::Parser::Resource) ? x : x.to_resource(@scope)}

      found_resources.each do |item|
        if existing = @scope.findresource(item.type, item.title)
          unless existing.collector_id == item.collector_id
            # unless this is the one we've already collected
            raise Puppet::ParseError,
              "A duplicate resource was found while collecting exported resources, with the type and title #{item.ref}"
          end
        else
          item.exported = false
          @scope.compiler.add_resource(@scope, item)
          resources << item
        end
      end
    end

    scope.debug("Collected %s %s resource%s in %.2f seconds" %
                [resources.length, @type, resources.length == 1 ? "" : "s", time])

    resources
  end

  def collect_resources
    @resources = [@resources] unless @resources.is_a?(Array)
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
    @scope.compiler.delete_collection(self) if @resources.empty?

    result
  end

  # Collect just virtual objects, from our local compiler.
  def collect_virtual(exported = false)
    scope.compiler.resources.find_all do |resource|
      resource.type == @type and (exported ? resource.exported? : true) and match?(resource)
    end
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
