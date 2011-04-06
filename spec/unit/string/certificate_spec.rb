require 'puppet/ssl/host'

describe Puppet::String[:certificate, '0.0.1'] do
  it "should have a ca-location option" do
    subject.should be_option :ca_location
  end

  it "should set the ca location when invoked" do
    pending "The string itself is broken in this release."
    Puppet::SSL::Host.expects(:ca_location=).with(:foo)
    Puppet::SSL::Host.indirection.expects(:search)
    subject.list :ca_location => :foo
  end
end
