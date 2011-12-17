#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/ocsp/ca'

describe Puppet::Indirector::Ocsp::Ca do
  it "should have documentation" do
    Puppet::Indirector::Ocsp::Ca.doc.should be_instance_of(String)
  end

  it "should ask for an ocsp respond on save" do
    request = stub 'request'
    indirector_request = stub 'indirector_request', :instance => request
    ca = Puppet::Indirector::Ocsp::Ca.new
    Puppet::SSL::Ocsp::Responder.expects(:respond).with(request)
    ca.save(indirector_request)
  end
end
