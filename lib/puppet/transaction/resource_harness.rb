require 'puppet/resource/status'

class Puppet::Transaction::ResourceHarness
    extend Forwardable
    def_delegators :@transaction, :relationship_graph

    attr_reader :transaction

    def allow_changes?(resource)
        return true unless resource.purging? and resource.deleting?
        return true unless deps = relationship_graph.dependents(resource) and ! deps.empty? and deps.detect { |d| ! d.deleting? }

        deplabel = deps.collect { |r| r.ref }.join(",")
        plurality = deps.length > 1 ? "":"s"
        resource.warning "#{deplabel} still depend#{plurality} on me -- not purging"
        return false
    end

    def apply_changes(status, changes)
        changes.each do |change|
            status << change.apply
        end
        status.changed = true
    end

    def changes_to_perform(status, resource)
        current = resource.retrieve

        if param = resource.parameter(:ensure)
            insync = param.insync?(current[:ensure])
            return [Puppet::Transaction::Change.new(param, current[:ensure])] unless insync
            return [] if param.should == :absent
        end

        resource.properties.reject { |p| p.name == :ensure }.find_all do |param|
            ! param.insync?(current[param.name])
        end.collect do |param|
            Puppet::Transaction::Change.new(param, current[param.name])
        end
    end

    def evaluate(resource)
        status = Puppet::Resource::Status.new(resource)

        if changes = changes_to_perform(status, resource) and ! changes.empty?
            status.out_of_sync = true
            apply_changes(status, changes)
            resource.cache(:synced, Time.now)
            resource.flush if resource.respond_to?(:flush)
        end
        return status
    rescue => detail
        resource.fail "Could not create resource status: #{detail}" unless status
        resource.err "Could not evaluate: #{detail}"
        status.failed = true
        return status
    end

    def initialize(transaction)
        @transaction = transaction
    end
end
