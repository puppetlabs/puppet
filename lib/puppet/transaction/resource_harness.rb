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

        resource.cache :checked, Time.now

        return [] if ! allow_changes?(resource)

        if param = resource.parameter(:ensure)
            return [] if absent_and_not_being_created?(current, param)
            return [Puppet::Transaction::Change.new(param, current[:ensure])] unless ensure_is_insync?(current, param)
            return [] if ensure_should_be_absent?(current, param)
        end

        resource.properties.reject { |p| p.name == :ensure }.reject do |param|
            param.should.nil?
        end.reject do |param|
            param_is_insync?(current, param)
        end.collect do |param|
            Puppet::Transaction::Change.new(param, current[param.name])
        end
    end

    def evaluate(resource)
        start = Time.now
        status = Puppet::Resource::Status.new(resource)

        if changes = changes_to_perform(status, resource) and ! changes.empty?
            status.out_of_sync = true
            status.change_count = changes.length
            apply_changes(status, changes)
            if ! resource.noop?
                resource.cache(:synced, Time.now)
                resource.flush if resource.respond_to?(:flush)
            end
        end
        return status
    rescue => detail
        resource.fail "Could not create resource status: #{detail}" unless status
        puts detail.backtrace if Puppet[:trace]
        resource.err "Could not evaluate: #{detail}"
        status.failed = true
        return status
    ensure
        (status.evaluation_time = Time.now - start) if status
    end

    def initialize(transaction)
        @transaction = transaction
    end

    private

    def absent_and_not_being_created?(current, param)
        current[:ensure] == :absent and param.should.nil?
    end

    def ensure_is_insync?(current, param)
        param.insync?(current[:ensure])
    end

    def ensure_should_be_absent?(current, param)
        param.should == :absent
    end

    def param_is_insync?(current, param)
        param.insync?(current[param.name])
    end
end
