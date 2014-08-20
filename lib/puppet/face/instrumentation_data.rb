require 'puppet/indirector/face'
require 'puppet/util/instrumentation/data'

Puppet::Indirector::Face.define(:instrumentation_data, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage instrumentation listener accumulated data. DEPRECATED."
  description <<-EOT
    This subcommand allows to retrieve the various listener data.
    (DEPRECATED) This subcommand will be removed in Puppet 4.0.
  EOT

  get_action(:destroy).summary "Invalid for this subcommand."
  get_action(:save).summary "Invalid for this subcommand."
  get_action(:search).summary "Invalid for this subcommand."

  find = get_action(:find)
  find.summary "Retrieve listener data."
  find.render_as = :pson
  find.returns <<-EOT
    The data of an instrumentation listener
  EOT
  find.examples <<-EOT
    Retrieve listener data:

    $ puppet instrumentation_data find performance --terminus rest
  EOT

end
