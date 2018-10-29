require 'puppet/application'

class Puppet::Application::Cert < Puppet::Application

  def summary
    _("Manage certificates and requests (Disabled)")
  end

  def help
     <<-HELP
This command is no longer functional, please use `puppetserver ca` instead.

puppet-cert(8) -- #{summary}
========

ACTIONS
-------
Every action except 'list' and 'generate' requires a hostname to act on,
unless the '--all' option is set.

* clean:
  Use `puppetserver ca clean --certname NAME[,NAME...]`

* fingerprint:
  Use openssl directly:
  `openssl x509 -noout -fingerprint -<digest> -inform pem -in certificate.crt`

* generate:
  Use `puppetserver ca generate --certname NAME[,NAME...]`

* list:
  Use `puppetserver ca list [--all]`

* print:
  Use openssl directly:
  `openssl x509 -noout -text -in certificate.pem`

* revoke:
  Use `puppetserver ca revoke --certname NAME[,NAME...]`

* sign:
  Use `puppetserver ca sign --certname NAME[,NAME...]`

* verify:
  Use `puppet ssl verify [--certname NAME]`

* reinventory:
  Removed.

OPTIONS
-------
There are a couple important notes about previously-supported options.

* --allow-dns-alt-names:
  In order to sign certificates with subject alternative names using
  `puppetserver ca sign`, the `allow-subject-alt-names` setting must be
  set to true in the `certificate-authority` section of Puppet Server's
  config.

* --allow-authorization-extensions:
  In order to sign certificates with authorization extensions using
  `puppetserver ca sign`, the `allow-authorization-extensions` setting must be
  set to true in the `certificate-authority` section of Puppet Server's
  config.
HELP
  end

  def setup
    deprecate
  end

  def parse_options
    puts help
    exit 1
  end
end
