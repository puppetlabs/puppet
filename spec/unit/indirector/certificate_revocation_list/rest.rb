#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/certificate_revocation_list/rest'

describe Puppet::SSL::CertificateRevocationList::Rest do
    before do
        @searcher = Puppet::SSL::CertificateRevocationList::Rest.new
    end

    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::SSL::CertificateRevocationList::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
