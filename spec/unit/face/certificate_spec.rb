#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

require 'puppet/ssl/host'

describe Puppet::Face[:certificate, '0.0.1'] do
  it "should have a ca-location option" do
    subject.should be_option :ca_location
  end

  it "should set the ca location when invoked" do
    Puppet::SSL::Host.expects(:ca_location=).with(:local)
    Puppet::SSL::Host.indirection.expects(:save)
    subject.sign "hello, friend", :ca_location => :local
  end

  it "(#7059) should set the ca location when an inherited action is invoked" do
    Puppet::SSL::Host.expects(:ca_location=).with(:local)
    subject.indirection.expects(:find)
    subject.find "hello, friend", :ca_location => :local
  end

  it "should validate the option as required" do
    expect do
      subject.find 'hello, friend'
    end.to raise_exception ArgumentError, /required/i
  end

  it "should validate the option as a supported value" do
    expect do
      subject.find 'hello, friend', :ca_location => :foo
    end.to raise_exception ArgumentError, /valid values/i
  end

  describe "#generate" do
    include PuppetSpec::Files

    let(:options) { {:ca_location => 'local'} }
    let(:host) { Puppet::SSL::Host.new(hostname) }
    let(:csr) { host.certificate_request }

    before :each do
      Puppet[:confdir] = tmpdir('conf')
      Puppet.settings.use(:main, :ca)
    end

    describe "for the current host" do
      let(:hostname) { Puppet[:certname] }

      it "should generate a CSR for this host" do
        subject.generate(hostname, options)

        csr.content.subject.to_s.should == "/CN=#{Puppet[:certname]}"
        csr.name.should == Puppet[:certname]
      end

      it "should add dns_alt_names from the global config if not otherwise specified" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options)

        expected = %W[DNS:from DNS:the DNS:config DNS:#{hostname}]

        csr.subject_alt_names.should =~ expected
      end

      it "should add the provided dns_alt_names if they are specified" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options.merge(:dns_alt_names => 'explicit,alt,names'))

        expected = %W[DNS:explicit DNS:alt DNS:names DNS:#{hostname}]

        csr.subject_alt_names.should =~ expected
      end
    end

    describe "for another host" do
      let(:hostname) { Puppet[:certname] + 'different' }

      it "should generate a CSR for the specified host" do
        subject.generate(hostname, options)

        csr.content.subject.to_s.should == "/CN=#{hostname}"
        csr.name.should == hostname
      end

      it "should fail if a CSR already exists for the host" do
        subject.generate(hostname, options)

        expect do
          subject.generate(hostname, options)
        end.to raise_error(RuntimeError, /#{hostname} already has a requested certificate; ignoring certificate request/)
      end

      it "should add not dns_alt_names from the config file" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options)

        csr.subject_alt_names.should be_empty
      end

      it "should add the provided dns_alt_names if they are specified" do
        Puppet[:dns_alt_names] = 'from,the,config'

        subject.generate(hostname, options.merge(:dns_alt_names => 'explicit,alt,names'))

        expected = %W[DNS:explicit DNS:alt DNS:names DNS:#{hostname}]

        csr.subject_alt_names.should =~ expected
      end
    end
  end
end
