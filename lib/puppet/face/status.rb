require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:status, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "View puppet server status"
  description <<-EOT
This subcommand is only useful for determining whether a puppet master
server (or an agent node, if puppet was started with the `--listen`
option) is responding to requests.

Only the `find` action is valid. If the server is responding to
requests, `find` will retrieve a status object; if not, the connection
will be refused. When invoked with the `local` terminus, `find` will
always return true.

If you wish to query a server other than the master configured in
puppet.conf, you must set the `--server` and `--masterport` options on
the command line.
  EOT
  notes <<-EOT
This is an indirector face, which exposes find, search, save, and
destroy actions for an indirected subsystem of Puppet. Valid terminuses
for this face include:

* `local`
* `rest`
  EOT
end
