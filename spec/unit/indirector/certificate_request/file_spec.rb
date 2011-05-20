#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2008-3-7.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/indirector/certificate_request/file'

describe Puppet::SSL::CertificateRequest::File do
  it "should have documentation" do
    Puppet::SSL::CertificateRequest::File.doc.should be_instance_of(String)
  end

  it "should use the :requestdir as the collection directory" do
    Puppet.settings.expects(:value).with(:requestdir).returns "/request/dir"
    Puppet::SSL::CertificateRequest::File.collection_directory.should == "/request/dir"
  end
end
