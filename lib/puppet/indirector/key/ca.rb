require 'puppet/indirector/ssl_file'
require 'puppet/ssl/key'

class Puppet::SSL::Key::Ca < Puppet::Indirector::SslFile
  desc "Manage the CA's private key on disk. This terminus works with the
    CA key *only*, because that's the only key that the CA ever interacts
    with."

  store_in :privatekeydir

  store_ca_at :cakey

  def allow_remote_requests?
    false
  end
end
