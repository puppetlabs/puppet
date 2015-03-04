#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/certificate_request/file'

describe Puppet::SSL::CertificateRequest::File do
  it "should have documentation" do
    expect(Puppet::SSL::CertificateRequest::File.doc).to be_instance_of(String)
  end

  it "should use the :requestdir as the collection directory" do
    Puppet[:requestdir] = File.expand_path("/request/dir")
    expect(Puppet::SSL::CertificateRequest::File.collection_directory).to eq(Puppet[:requestdir])
  end
end
