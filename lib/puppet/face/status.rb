require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:status, '0.0.1') do
  copyright "Puppet Inc.", 2011
  license   _("Apache 2 license; see COPYING")

  summary _("View puppet server status.")

  deactivate_action(:destroy)
  deactivate_action(:save)
  deactivate_action(:search)

  find = get_action(:find)
  find.default = true
  find.summary _("Check status of puppet master server.")
  #TRANSLATORS the string 'Puppet::Status' is a Puppet language object and should not be translated
  find.returns _(<<-'EOT')
    A "true" response or a low-level connection error. When used from the Ruby
    API: returns a Puppet::Status object.
  EOT
  find.description <<-'EOT'
    Checks whether a Puppet server is properly receiving and processing
    HTTP requests. This action is only useful when used with '--terminus
    rest'; when invoked with the `local` terminus, `find` will always
    return true.

    Over REST, this action will query the configured puppet master by default.
    To query other servers, including puppet agent nodes started with the
    <--listen> option, you can set the global <--server> and <--masterport>
    options on the command line; note that agent nodes listen on port 8139.
  EOT
  find.short_description <<-EOT
    Checks whether a Puppet server is properly receiving and processing HTTP
    requests. This action is only useful when used with '--terminus rest',
    and will always return true when invoked locally.
  EOT
  find.notes <<-'EOT'
    This action requires that the server's `auth.conf` file allow find
    access to the `status` REST terminus. Puppet agent does not use this
    facility, and it is turned off by default. See
    <https://docs.puppetlabs.com/puppet/latest/reference/config_file_auth.html>
    for more details.
  EOT
  find.examples <<-'EOT'
    Check the status of the configured puppet master:

    $ puppet status find --terminus rest
  EOT
  
  deprecate
end
