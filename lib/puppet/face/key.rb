require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:key, '0.0.1') do
  summary "Create, save, and remove certificate keys."

  @longdocs = "Keys are created for you automatically when certificate
  requests are generated with 'puppet certificate generate'."
end
