require 'puppet/rails/host'
require 'puppet/indirector/active_record'
require 'puppet/resource/catalog'

class Puppet::Resource::Catalog::ActiveRecord < Puppet::Indirector::ActiveRecord
    use_ar_model Puppet::Rails::Host

    # If we can find the host, then return a catalog with the host's resources
    # as the vertices.
    def find(request)
        return nil unless request.options[:cache_integration_hack]
        return nil unless host = ar_model.find_by_name(request.key)

        catalog = Puppet::Resource::Catalog.new(host.name)

        host.resources.each do |resource|
            catalog.add_resource resource.to_transportable
        end

        catalog
    end

    # Save the values from a Facts instance as the facts on a Rails Host instance.
    def save(request)
        catalog = request.instance

        host = ar_model.find_by_name(catalog.name) || ar_model.create(:name => catalog.name)

        host.railsmark "Saved catalog to database" do
            host.merge_resources(catalog.vertices)
            host.last_compile = Time.now

            if node = Puppet::Node.find(catalog.name)
                host.ip = node.parameters["ipaddress"]
                host.environment = node.environment
            end

            host.save
        end
    end
end
