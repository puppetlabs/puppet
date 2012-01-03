require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:instrumentation_listener, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage instrumentation listeners."
  description <<-EOT
    This subcommand enables/disables or list instrumentation listeners.
  EOT

  get_action(:destroy).summary "Invalid for this subcommand."

  find = get_action(:find)
  find.summary "Retrieve a single listener."
  find.render_as = :pson
  find.returns <<-EOT
    The status of an instrumentation listener
  EOT
  find.examples <<-EOT
    Retrieve a given listener:

    $ puppet instrumentation_listener find performance --terminus rest
  EOT

  search = get_action(:search)
  search.summary "Retrieve all instrumentation listeners statuses."
  search.arguments "<dummy_text>"
  search.render_as = :pson
  search.returns <<-EOT
    The statuses of all instrumentation listeners
  EOT
  search.short_description <<-EOT
    This retrieves all instrumentation listeners
  EOT
  search.notes <<-EOT
    Although this action always returns all instrumentation listeners, it requires a dummy search
    key; this is a known bug.
  EOT
  search.examples <<-EOT
    Retrieve the state of the listeners running in the remote puppet master:

    $ puppet instrumentation_listener search x --terminus rest
  EOT

  def manage(name, activate)
    Puppet::Util::Instrumentation::Listener.indirection.terminus_class = :rest
    listener = Puppet::Face[:instrumentation_listener, '0.0.1'].find(name)
    if listener
      listener.enabled = activate
      Puppet::Face[:instrumentation_listener, '0.0.1'].save(listener)
    end
  end

  action :enable do
    summary "Enable a given instrumentation listener."
    arguments "<listener>"
    returns "Nothing."
    description <<-EOT
      Enable a given instrumentation listener. After being enabled the listener
      will start receiving instrumentation notifications from the probes if those
      are enabled.
    EOT
    examples <<-EOT
      Enable the "performance" listener in the running master:

      $ puppet instrumentation_listener enable performance --terminus rest
    EOT

    when_invoked do |name, options|
      manage(name, true)
    end
  end

  action :disable do
    summary "Disable a given instrumentation listener."
    arguments "<listener>"
    returns "Nothing."
    description <<-EOT
      Disable a given instrumentation listener. After being disabled the listener
      will stop receiving instrumentation notifications from the probes.
    EOT
    examples <<-EOT
      Disable the "performance" listener in the running master:

      $ puppet instrumentation_listener disable performance --terminus rest
    EOT

    when_invoked do |name, options|
      manage(name, false)
    end
  end

  get_action(:save).summary "API only: modify an instrumentation listener status."
  get_action(:save).arguments "<listener>"
end
