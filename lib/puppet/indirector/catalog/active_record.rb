require 'puppet/rails/host'
require 'puppet/indirector/active_record'
require 'puppet/node/catalog'

class Puppet::Node::Catalog::ActiveRecord < Puppet::Indirector::ActiveRecord
    use_ar_model Puppet::Rails::Host

    # If we can find the host, then return a catalog with the host's resources
    # as the vertices.
    def find(request)
        return nil unless request.options[:cache_integration_hack]
        return nil unless host = ar_model.find_by_name(request.key)

        catalog = Puppet::Node::Catalog.new(host.name)
        
        host.resources.each do |resource|
            catalog.add_resource resource.to_transportable
        end

        catalog
    end

    # Save the values from a Facts instance as the facts on a Rails Host instance.
    def save(request)
        catalog = request.instance

        host = ar_model.find_by_name(catalog.name) || ar_model.create(:name => catalog.name)

        host.setresources(catalog.vertices)
        host.last_compile = Time.now

        host.save
    end
end
