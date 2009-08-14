require 'puppet/rails/host'
require 'puppet/indirector/active_record'
require 'puppet/node'

class Puppet::Node::ActiveRecord < Puppet::Indirector::ActiveRecord
    use_ar_model Puppet::Rails::Host

    def find(request)
        node = super
        node.fact_merge
        node
    end
end
