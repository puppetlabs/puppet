require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:resource, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact directly with resources via the RAL, like ralsh"
  description <<-'EOT'
    This face provides a Ruby API with functionality similar to the puppet
    resource (originally ralsh) command line application. It is not intended to be
    used from the command line.
  EOT
  notes <<-'EOT'
    This is an indirector face, which exposes `find`, `search`, `save`, and
    `destroy` actions for an indirected subsystem of Puppet. Valid termini
    for this face include:

    * `ral`
    * `rest`
  EOT

  get_action(:destroy).summary "Invalid for this face."

  search = get_action(:search)
  search.summary "Get all resources of a single type."
  search.arguments "<resource_type>"
  search.returns "An array of resource objects."
  search.examples <<-'EOT'
    Get a list of all user resources (API example):

        all_users = Puppet::Face[:resource, '0.0.1'].search("user")
  EOT

  find = get_action(:find)
  find.summary "Get a single resource."
  find.arguments "<type>/<title>"
  find.returns "A resource object."
  find.examples <<-'EOT'
    Print information about a user on this system (API example):

        puts Puppet::Face[:resource, '0.0.1'].find("user/luke").to_pson
  EOT

  save = get_action(:save)
  save.summary "Create a new resource."
  save.arguments "<resource_object>"
  save.returns "The same resource object passed."
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
