require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:resource, '0.0.1') do
  copyright "Puppet Inc.", 2011
  license   _("Apache 2 license; see COPYING")

  summary _("API only: interact directly with resources via the RAL.")
  description <<-'EOT'
    API only: this face provides a Ruby API with functionality similar to the
    puppet resource subcommand.
  EOT

  deactivate_action(:destroy)

  search = get_action(:search)
  search.summary _("API only: get all resources of a single type.")
  search.arguments _("<resource_type>")
  search.returns _("An array of Puppet::Resource objects.")
  search.examples <<-'EOT'
    Get a list of all user resources (API example):

        all_users = Puppet::Face[:resource, '0.0.1'].search("user")
  EOT

  find = get_action(:find)
  find.summary _("API only: get a single resource.")
  find.arguments _("<type>/<title>")
  find.returns _("A Puppet::Resource object.")
  find.examples <<-'EOT'
    Print information about a user on this system (API example):

        puts Puppet::Face[:resource, '0.0.1'].find("user/luke").to_json
  EOT

  save = get_action(:save)
  save.summary _("API only: create a new resource.")
  save.description <<-EOT
    API only: creates a new resource.
  EOT
  save.arguments _("<resource_object>")
  save.returns _("The same resource object passed as an argument.")
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
