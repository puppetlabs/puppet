require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:key, '0.0.1') do
  copyright "Puppet Inc.", 2011
  license   _("Apache 2 license; see COPYING")

  summary _("Create, save, and remove certificate keys.")
  description <<-'EOT'
    This subcommand manages certificate private keys. Keys are created
    automatically by puppet agent and when certificate requests are generated
    with 'puppet certificate generate'; it should not be necessary to use this
    subcommand directly.
  EOT

  deprecate
end
