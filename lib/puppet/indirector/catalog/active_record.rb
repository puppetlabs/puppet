require 'puppet/rails/host'
require 'puppet/indirector/active_record'
require 'puppet/resource/catalog'

class Puppet::Resource::Catalog::ActiveRecord < Puppet::Indirector::ActiveRecord
  use_ar_model Puppet::Rails::Host

  desc "A component of ActiveRecord storeconfigs. ActiveRecord-based storeconfigs
    and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"

  def initialize
    Puppet.deprecation_warning "ActiveRecord-based storeconfigs and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"
    super
  end

  # We don't retrieve catalogs from storeconfigs
  def find(request)
    nil
  end

  # Save the values from a Facts instance as the facts on a Rails Host instance.
  def save(request)
    catalog = request.instance

    host = ar_model.find_by_name(catalog.name) || ar_model.create(:name => catalog.name)

    host.railsmark "Saved catalog to database" do
      host.merge_resources(catalog.vertices)
      host.last_compile = Time.now

      if node = Puppet::Node.indirection.find(catalog.name)
        host.ip = node.parameters["ipaddress"]
        host.environment = node.environment.to_s
      end

      host.save
    end
  end
end
