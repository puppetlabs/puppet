#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-3-7.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/indirector/certificate_request/ca'

describe Puppet::SSL::CertificateRequest::Ca do
  it "should have documentation" do
    Puppet::SSL::CertificateRequest::Ca.doc.should be_instance_of(String)
  end

  it "should use the :csrdir as the collection directory" do
    Puppet.settings.expects(:value).with(:csrdir).returns "/request/dir"
    Puppet::SSL::CertificateRequest::Ca.collection_directory.should == "/request/dir"
  end
end
