require 'puppet/ssl/host'

describe Puppet::Face[:certificate, '0.0.1'] do
  it "should have a ca-location option" do
    subject.should be_option :ca_location
  end

  it "should set the ca location when invoked" do
    pending "#6983: This is broken in the actual face..."
    Puppet::SSL::Host.expects(:ca_location=).with(:foo)
    Puppet::SSL::Host.indirection.expects(:save)
    subject.sign :ca_location => :foo
  end
end
