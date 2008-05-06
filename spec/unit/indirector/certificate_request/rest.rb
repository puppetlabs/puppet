#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/certificate_request/rest'

describe Puppet::SSL::CertificateRequest::Rest do
    before do
        @searcher = Puppet::SSL::CertificateRequest::Rest.new
    end

    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::SSL::CertificateRequest::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
