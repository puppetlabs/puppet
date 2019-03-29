require 'spec_helper'

require 'puppet/indirector/node/ldap'

describe Puppet::Node::Ldap do
  it "should use a restrictive filter when searching for nodes in a class" do
    ldap = Puppet::Node.indirection.terminus(:ldap)
    allow(Puppet::Node.indirection).to receive(:terminus).and_return(ldap)
    expect(ldap).to receive(:ldapsearch).with("(&(objectclass=puppetClient)(puppetclass=foo))")

    Puppet::Node.indirection.search "eh", :class => "foo"
  end
end
