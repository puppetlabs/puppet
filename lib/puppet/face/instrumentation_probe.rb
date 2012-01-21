require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:instrumentation_probe, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage instrumentation probes."
  description <<-EOT
    This subcommand enables/disables or list instrumentation listeners.
  EOT

  get_action(:find).summary "Invalid for this subcommand."

  search = get_action(:search)
  search.summary "Retrieve all probe statuses."
  search.arguments "<dummy_text>"
  search.render_as = :pson
  search.returns <<-EOT
    The statuses of all instrumentation probes
  EOT
  search.short_description <<-EOT
    This retrieves all instrumentation probes
  EOT
  search.notes <<-EOT
    Although this action always returns all instrumentation probes, it requires a dummy search
    key; this is a known bug.
  EOT
  search.examples <<-EOT
    Retrieve the state of the probes running in the remote puppet master:

    $ puppet instrumentation_probe search x --terminus rest
  EOT

  action :enable do
    summary "Enable all instrumentation probes."
    arguments "<dummy>"
    returns "Nothing."
    description <<-EOT
      Enable all instrumentation probes. After being enabled, all enabled listeners
      will start receiving instrumentation notifications from the probes.
    EOT
    examples <<-EOT
      Enable the probes for the running master:

      $ puppet instrumentation_probe enable x --terminus rest
    EOT

    when_invoked do |name, options|
      Puppet::Face[:instrumentation_probe, '0.0.1'].save(nil)
    end
  end

  action :disable do
    summary "Disable all instrumentation probes."
    arguments "<dummy>"
    returns "Nothing."
    description <<-EOT
      Disable all instrumentation probes. After being disabled, no listeners
      will receive instrumentation notifications.
    EOT
    examples <<-EOT
      Disable the probes for the running master:

      $ puppet instrumentation_probe disable x --terminus rest
    EOT

    when_invoked do |name, options|
      Puppet::Face[:instrumentation_probe, '0.0.1'].destroy(nil)
    end
  end

  get_action(:save).summary "API only: enable all instrumentation probes."
  get_action(:save).arguments "<dummy>"

  get_action(:destroy).summary "API only: disable all instrumentation probes."
  get_action(:destroy).arguments "<dummy>"
end
