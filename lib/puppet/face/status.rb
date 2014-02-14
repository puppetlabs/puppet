require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:status, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "View puppet server status."

  get_action(:destroy).summary "Invalid for this subcommand."
  get_action(:save).summary "Invalid for this subcommand."
  get_action(:save).description "Invalid for this subcommand."
  get_action(:search).summary "Invalid for this subcommand."

  find = get_action(:find)
  find.default = true
  find.summary "Check status of puppet master server."
  find.arguments "<dummy_text>"
  find.returns <<-'EOT'
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
    requests. Due to a known bug, this action requires a dummy argument, the
    content of which is irrelevant. This action is only useful when used with
    '--terminus rest', and will always return true when invoked locally.
  EOT
  find.notes <<-'EOT'
    This action requires that the server's `auth.conf` file allow find
    access to the `status` REST terminus. Puppet agent does not use this
    facility, and it is turned off by default. See
    <http://docs.puppetlabs.com/guides/rest_auth_conf.html> for more details.

    Although this action always returns an unnamed status object, it requires a
    dummy argument. This is a known bug.
  EOT
  find.examples <<-'EOT'
    Check the status of the configured puppet master:

    $ puppet status find x --terminus rest
  EOT
end
