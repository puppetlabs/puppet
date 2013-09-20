#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe "Puppet::Util::Windows::RootCerts", :if => Puppet::Util::Platform.windows? do
  let(:klass) { Puppet::Util::Windows::RootCerts }
  let(:x509) { 'mycert' }

  context '#each' do
    it "should enumerate each root cert" do
      klass.expects(:load_certs).returns([x509])
      klass.instance.to_a.should == [x509]
    end
  end
end
