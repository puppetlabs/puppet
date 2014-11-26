require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:resource, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "API only: interact directly with resources via the RAL."
  description <<-'EOT'
    API only: this face provides a Ruby API with functionality similar to the
    puppet resource subcommand.
  EOT

  deactivate_action(:destroy)

  search = get_action(:search)
  search.summary "API only: get all resources of a single type."
  search.arguments "<resource_type>"
  search.returns "An array of Puppet::Resource objects."
  search.examples <<-'EOT'
    Get a list of all user resources (API example):

        all_users = Puppet::Face[:resource, '0.0.1'].search("user")
  EOT

  find = get_action(:find)
  find.summary "API only: get a single resource."
  find.arguments "<type>/<title>"
  find.returns "A Puppet::Resource object."
  find.examples <<-'EOT'
    Print information about a user on this system (API example):

        puts Puppet::Face[:resource, '0.0.1'].find("user/luke").to_pson
  EOT

  save = get_action(:save)
  save.summary "API only: create a new resource."
  save.description <<-EOT
    API only: creates a new resource.
  EOT
  save.arguments "<resource_object>"
  save.returns "The same resource object passed as an argument."
  save.examples <<-'EOT'
    Create a new file resource (API example):

        my_resource = Puppet::Resource.new(
          :file,
          "/tmp/demonstration",
          :parameters => {:ensure => :present, :content => "some\nthing\n"}
        )

        Puppet::Face[:resource, '0.0.1'].save(my_resource)
  EOT
end
