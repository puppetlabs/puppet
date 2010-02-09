#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/ssl/certificate'
require 'puppet/network/server'
require 'puppet/network/http/webrick/rest'

describe "Certificate REST Terminus" do
    before do
        Puppet[:masterport] = 34343
        Puppet[:server] = "localhost"

        # Get a safe temporary file
        @tmpfile = Tempfile.new("webrick_integration_testing")
        @dir = @tmpfile.path + "_dir"

        Puppet.settings[:confdir] = @dir
        Puppet.settings[:vardir] = @dir
        Puppet.settings[:server] = "127.0.0.1"
        Puppet.settings[:masterport] = "34343"

        Puppet::Util::Cacher.expire

        Puppet[:servertype] = 'webrick'
        Puppet[:server] = '127.0.0.1'
        Puppet[:certname] = '127.0.0.1'

        # Generate the certificate with a local CA
        Puppet::SSL::Host.ca_location = :local
        ca = Puppet::SSL::CertificateAuthority.new
        ca.generate(Puppet[:certname]) unless Puppet::SSL::Certificate.find(Puppet[:certname])

        @params = { :port => 34343, :handlers => [ :certificate_revocation_list ] }
        @server = Puppet::Network::Server.new(@params)
        @server.listen

        # And make sure we've generated the CRL
        @crl = ca.crl

        # Now remove the cached crl
        Puppet::SSL::Host.ca_location = :none
        Puppet::SSL::CertificateRevocationList.destroy(Puppet::SSL::CA_NAME)

        # This is necessary so that we create the SSL store before we start
        # using REST.  This is necessary to prevent an infinite loop,
        # which only occurs during testing.
        Puppet::Network::HttpPool.ssl_host.ssl_store

        # Then switch to a remote CA, so that we go through REST.
        Puppet::SSL::Host.ca_location = :remote

        # LAK:NOTE We need to have a fake model here so that our indirected methods get
        # passed through REST; otherwise we'd be stubbing 'find', which would cause an immediate
        # return.
        @mock_model = stub('faked model', :name => "certificate")
        Puppet::Indirector::Request.any_instance.stubs(:model).returns(@mock_model)

        Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:check_authorization).returns(true)
    end

    after do
        Puppet::Network::HttpPool.expire
        Puppet::SSL::Host.ca_location = :none
        Puppet.settings.clear
        @server.unlisten
    end

    it "should be able to retrieve a remote CRL" do
        @mock_model.expects(:find).returns @crl
        result = Puppet::SSL::CertificateRevocationList.find('bar')

        # There's no good '==' method on certs.
        result.content.to_s.should == @crl.content.to_s
    end
end
