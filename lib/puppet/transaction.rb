# the class that actually walks our resource/property tree, collects the changes,
# and performs them

require 'puppet'
require 'puppet/util/tagging'
require 'puppet/application'

class Puppet::Transaction
    require 'puppet/transaction/change'
    require 'puppet/transaction/event'
    require 'puppet/transaction/event_manager'
    require 'puppet/transaction/resource_harness'
    require 'puppet/resource/status'

    attr_accessor :component, :catalog, :ignoreschedules
    attr_accessor :sorted_resources, :configurator

    # The report, once generated.
    attr_accessor :report

    # Routes and stores any events and subscriptions.
    attr_reader :event_manager

    # Handles most of the actual interacting with resources
    attr_reader :resource_harness

    include Puppet::Util
    include Puppet::Util::Tagging

    # Wraps application run state check to flag need to interrupt processing
    def stop_processing?
        Puppet::Application.stop_requested?
    end

    # Add some additional times for reporting
    def add_times(hash)
        hash.each do |name, num|
            report.add_times(name, num)
        end
    end

    # Are there any failed resources in this transaction?
    def any_failed?
        report.resource_statuses.values.detect { |status| status.failed? }
    end

    # Apply all changes for a resource
    def apply(resource, ancestor = nil)
        status = resource_harness.evaluate(resource)
        add_resource_status(status)
        event_manager.queue_events(ancestor || resource, status.events)
    rescue => detail
        resource.err "Could not evaluate: #{detail}"
    end

    # Find all of the changed resources.
    def changed?
        report.resource_statuses.values.find_all { |status| status.changed }.collect { |status| catalog.resource(status.resource) }
    end

    # Copy an important relationships from the parent to the newly-generated
    # child resource.
    def make_parent_child_relationship(resource, children)
        depthfirst = resource.depthfirst?

        children.each do |gen_child|
            if depthfirst
                edge = [gen_child, resource]
            else
                edge = [resource, gen_child]
            end
            relationship_graph.add_vertex(gen_child)

            unless relationship_graph.edge?(edge[1], edge[0])
                relationship_graph.add_edge(*edge)
            else
                resource.debug "Skipping automatic relationship to %s" % gen_child
            end
        end
    end

    # See if the resource generates new resources at evaluation time.
    def eval_generate(resource)
        generate_additional_resources(resource, :eval_generate)
    end

    # Evaluate a single resource.
    def eval_resource(resource, ancestor = nil)
        if skip?(resource)
            resource_status(resource).skipped = true
        else
            eval_children_and_apply_resource(resource, ancestor)
        end

        # Check to see if there are any events queued for this resource
        event_manager.process_events(resource)
    end

    def eval_children_and_apply_resource(resource, ancestor = nil)
        resource_status(resource).scheduled = true

        # We need to generate first regardless, because the recursive
        # actions sometimes change how the top resource is applied.
        children = eval_generate(resource)

        if ! children.empty? and resource.depthfirst?
            children.each do |child|
                # The child will never be skipped when the parent isn't
                eval_resource(child, ancestor || resource)
            end
        end

        # Perform the actual changes
        apply(resource, ancestor)

        if ! children.empty? and ! resource.depthfirst?
            children.each do |child|
                eval_resource(child, ancestor || resource)
            end
        end
    end

    # This method does all the actual work of running a transaction.  It
    # collects all of the changes, executes them, and responds to any
    # necessary events.
    def evaluate
        # Start logging.
        Puppet::Util::Log.newdestination(@report)

        prepare()

        Puppet.info "Applying configuration version '%s'" % catalog.version if catalog.version

        begin
            @sorted_resources.each do |resource|
                next if stop_processing?
                if resource.is_a?(Puppet::Type::Component)
                    Puppet.warning "Somehow left a component in the relationship graph"
                    next
                end
                ret = nil
                seconds = thinmark do
                    ret = eval_resource(resource)
                end

                if Puppet[:evaltrace] and @catalog.host_config?
                    resource.info "Evaluated in %0.2f seconds" % seconds
                end
                ret
            end
        ensure
            # And then close the transaction log.
            Puppet::Util::Log.close(@report)
        end

        Puppet.debug "Finishing transaction #{object_id}"
    end

    def events
        event_manager.events
    end

    def failed?(resource)
        s = resource_status(resource) and s.failed?
    end

    # Does this resource have any failed dependencies?
    def failed_dependencies?(resource)
        # First make sure there are no failed dependencies.  To do this,
        # we check for failures in any of the vertexes above us.  It's not
        # enough to check the immediate dependencies, which is why we use
        # a tree from the reversed graph.
        found_failed = false
        relationship_graph.dependencies(resource).each do |dep|
            next unless failed?(dep)
            resource.notice "Dependency #{dep} has failures: #{resource_status(dep).failed}"
            found_failed = true
        end

        return found_failed
    end

    # A general method for recursively generating new resources from a
    # resource.
    def generate_additional_resources(resource, method)
        return [] unless resource.respond_to?(method)
        begin
            made = resource.send(method)
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            resource.err "Failed to generate additional resources using '%s': %s" % [method, detail]
        end
        return [] unless made
        made = [made] unless made.is_a?(Array)
        made.uniq.find_all do |res|
            begin
                res.tag(*resource.tags)
                @catalog.add_resource(res) do |r|
                    r.finish
                    make_parent_child_relationship(resource, [r])
                end
                true
            rescue Puppet::Resource::Catalog::DuplicateResourceError
                res.info "Duplicate generated resource; skipping"
                false
            end
        end
    end

    # Collect any dynamically generated resources.  This method is called
    # before the transaction starts.
    def generate
        list = @catalog.vertices
        newlist = []
        while ! list.empty?
            list.each do |resource|
                newlist += generate_additional_resources(resource, :generate)
            end
            list = newlist
            newlist = []
        end
    end

    # Generate a transaction report.
    def generate_report
        @report.calculate_metrics
        return @report
    end

    # Should we ignore tags?
    def ignore_tags?
        ! (@catalog.host_config? or Puppet[:name] == "puppet")
    end

    # this should only be called by a Puppet::Type::Component resource now
    # and it should only receive an array
    def initialize(catalog)
        @catalog = catalog

        @report = Report.new

        @event_manager = Puppet::Transaction::EventManager.new(self)

        @resource_harness = Puppet::Transaction::ResourceHarness.new(self)
    end

    # Prefetch any providers that support it.  We don't support prefetching
    # types, just providers.
    def prefetch
        prefetchers = {}
        @catalog.vertices.each do |resource|
            if provider = resource.provider and provider.class.respond_to?(:prefetch)
                prefetchers[provider.class] ||= {}
                prefetchers[provider.class][resource.name] = resource
            end
        end

        # Now call prefetch, passing in the resources so that the provider instances can be replaced.
        prefetchers.each do |provider, resources|
            Puppet.debug "Prefetching %s resources for %s" % [provider.name, provider.resource_type.name]
            begin
                provider.prefetch(resources)
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                Puppet.err "Could not prefetch %s provider '%s': %s" % [provider.resource_type.name, provider.name, detail]
            end
        end
    end

    # Prepare to evaluate the resources in a transaction.
    def prepare
        # Now add any dynamically generated resources
        generate()

        # Then prefetch.  It's important that we generate and then prefetch,
        # so that any generated resources also get prefetched.
        prefetch()

        # This will throw an error if there are cycles in the graph.
        @sorted_resources = relationship_graph.topsort
    end

    def relationship_graph
        catalog.relationship_graph
    end

    # Send off the transaction report.
    def send_report
        begin
            report = generate_report()
        rescue => detail
            Puppet.err "Could not generate report: %s" % detail
            return
        end

        if Puppet[:summarize]
            puts report.summary
        end

        if Puppet[:report]
            begin
                report.save()
            rescue => detail
                Puppet.err "Reporting failed: %s" % detail
            end
        end
    end

    def add_resource_status(status)
        report.add_resource_status status
    end

    def resource_status(resource)
        report.resource_statuses[resource.to_s] || add_resource_status(Puppet::Resource::Status.new(resource))
    end

    # Is the resource currently scheduled?
    def scheduled?(resource)
        self.ignoreschedules or resource.scheduled?
    end

    # Should this resource be skipped?
    def skip?(resource)
        skip = false
        if missing_tags?(resource)
            resource.debug "Not tagged with %s" % tags.join(", ")
        elsif ! scheduled?(resource)
            resource.debug "Not scheduled"
        elsif failed_dependencies?(resource)
            resource.warning "Skipping because of failed dependencies"
        elsif resource.virtual?
            resource.debug "Skipping because virtual"
        else
            return false
        end
        return true
    end

    # The tags we should be checking.
    def tags
        unless defined? @tags
            self.tags = Puppet[:tags]
        end

        super
    end

    def handle_qualified_tags( qualified )
        # The default behavior of Puppet::Util::Tagging is
        # to split qualified tags into parts. That would cause
        # qualified tags to match too broadly here.
        return
    end

    # Is this resource tagged appropriately?
    def missing_tags?(resource)
        not appropriately_tagged?(resource)
    end

    def appropriately_tagged?(resource)
        self.ignore_tags? or tags.empty? or resource.tagged?(*tags)
    end
end

require 'puppet/transaction/report'

