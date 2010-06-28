#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/ssl/certificate_request'
require 'puppet/network/server'
require 'puppet/network/http/webrick/rest'

describe "Certificate Request REST Terminus" do
    before do
        Puppet::Util::Cacher.expire

        Puppet[:masterport] = 34343
        Puppet[:server] = "localhost"

        # Get a safe temporary file
        @tmpfile = Tempfile.new("webrick_integration_testing")
        @dir = @tmpfile.path + "_dir"

        Puppet.settings[:confdir] = @dir
        Puppet.settings[:vardir] = @dir
        Puppet.settings[:server] = "127.0.0.1"
        Puppet.settings[:masterport] = "34343"

        Puppet[:servertype] = 'webrick'
        Puppet[:server] = '127.0.0.1'
        Puppet[:certname] = '127.0.0.1'

        # Generate the certificate with a local CA
        Puppet::SSL::Host.ca_location = :local
        ca = Puppet::SSL::CertificateAuthority.new
        ca.generate(Puppet[:certname]) unless Puppet::SSL::Certificate.find(Puppet[:certname])

        # Create the CSR and write it to disk
        @host = Puppet::SSL::Host.new("foo.madstop.com")
        @host.generate_certificate_request

        # Now remove the cached csr
        Puppet::SSL::Host.ca_location = :none
        Puppet::SSL::Host.destroy("foo.madstop.com")

        @params = { :port => 34343, :handlers => [ :certificate_request ] }
        @server = Puppet::Network::Server.new(@params)
        @server.listen

        # Then switch to a remote CA, so that we go through REST.
        Puppet::SSL::Host.ca_location = :remote

        # LAK:NOTE We need to have a fake model here so that our indirected methods get
        # passed through REST; otherwise we'd be stubbing 'find', which would cause an immediate
        # return.
        @mock_model = stub('faked model', :name => "certificate request")
        Puppet::Indirector::Request.any_instance.stubs(:model).returns(@mock_model)

        Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:check_authorization).returns(true)
    end

    after do
        Puppet::Network::HttpPool.expire
        Puppet::SSL::Host.ca_location = :none
        Puppet.settings.clear
        @server.unlisten
    end

    it "should be able to save a certificate request to the CA" do
        key = Puppet::SSL::Key.new("bar.madstop.com")
        key.generate

        csr = Puppet::SSL::CertificateRequest.new("bar.madstop.com")
        csr.generate(key.content)

        server_csr = mock 'csr'
        server_csr.expects(:save)
        @mock_model.expects(:convert_from).with("s", csr.content.to_s).returns server_csr

        csr.save
    end

    it "should be able to retrieve a remote certificate request" do
        # We're finding the cached value :/
        @mock_model.expects(:find).returns @host.certificate_request
        result = Puppet::SSL::CertificateRequest.find('foo.madstop.com')

        # There's no good '==' method on certs.
        result.content.to_s.should == @host.certificate_request.content.to_s
        result.name.should == @host.certificate_request.name
    end
end
