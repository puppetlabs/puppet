require 'spec_helper'

RSpec.shared_context('https client') do
  before :all do
    WebMock.disable!
  end

  after :all do
    WebMock.enable!
  end

  before :each do
    # make sure we don't take too long
    Puppet[:http_connect_timeout] = '5s'
    Puppet[:server] = '127.0.0.1'
    Puppet[:certname] = '127.0.0.1'

    Puppet[:localcacert] = File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'ca.pem')
    Puppet[:hostcrl] = File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'crl.pem')
    Puppet[:hostprivkey] = File.join(PuppetSpec::FIXTURE_DIR, 'ssl', '127.0.0.1-key.pem')
    Puppet[:hostcert] = File.join(PuppetSpec::FIXTURE_DIR, 'ssl', '127.0.0.1.pem')

    # set in memory facts since certname is changed above
    facts = Puppet::Node::Facts.new(Puppet[:certname])
    Puppet::Node::Facts.indirection.save(facts)
  end

  let(:https_server) { PuppetSpec::HTTPSServer.new }
end
