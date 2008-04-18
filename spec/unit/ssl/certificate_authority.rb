#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate_authority'

describe Puppet::SSL::CertificateAuthority do
    describe "when initializing" do
        before do
            Puppet.settings.stubs(:use)
            Puppet.settings.stubs(:value).returns "whatever"

            Puppet::SSL::CertificateAuthority.any_instance.stubs(:generate_ca_certificate)
        end

        it "should always set its name to the value of :certname" do
            Puppet.settings.expects(:value).with(:certname).returns "whatever"

            Puppet::SSL::CertificateAuthority.new.name.should == "whatever"
        end

        it "should create an SSL::Host instance whose name is the 'ca_name'" do
            Puppet::SSL::Host.expects(:ca_name).returns "caname"

            host = stub 'host'
            Puppet::SSL::Host.expects(:new).with("caname").returns host

            Puppet::SSL::CertificateAuthority.new
        end

        it "should use the :main, :ca, and :ssl settings sections" do
            Puppet.settings.expects(:use).with(:main, :ssl, :ca)
            Puppet::SSL::CertificateAuthority.new
        end

        it "should create an inventory instance" do
            Puppet::SSL::Inventory.expects(:new).returns "inventory"

            Puppet::SSL::CertificateAuthority.new.inventory.should == "inventory"
        end
    end

    describe "when generating a self-signed CA certificate" do
        before do
            Puppet.settings.stubs(:use)
            Puppet.settings.stubs(:value).returns "whatever"

            @ca = Puppet::SSL::CertificateAuthority.new

            @host = stub 'host', :key => mock("key"), :name => "hostname"

            Puppet::SSL::CertificateRequest.any_instance.stubs(:generate)

            @ca.stubs(:host).returns @host
        end

        it "should create and store a password at :capass" do
            Puppet.settings.expects(:value).with(:capass).returns "/path/to/pass"

            FileTest.expects(:exist?).with("/path/to/pass").returns false

            fh = mock 'filehandle'
            Puppet.settings.expects(:write).with(:capass).yields fh

            fh.expects(:print).with { |s| s.length > 18 }

            @ca.stubs(:sign)

            @ca.generate_ca_certificate
        end

        it "should generate a key if one does not exist" do
            @ca.stubs :generate_password
            @ca.stubs :sign

            @ca.host.expects(:key).returns nil
            @ca.host.expects(:generate_key)

            @ca.generate_ca_certificate
        end

        it "should create and sign a self-signed cert using the CA name" do
            request = mock 'request'
            Puppet::SSL::CertificateRequest.expects(:new).with(@ca.host.name).returns request
            request.expects(:generate).with(@ca.host.key)

            @ca.expects(:sign).with(@host.name, :ca, request)

            @ca.stubs :generate_password

            @ca.generate_ca_certificate
        end
    end

    describe "when signing" do
        before do
            Puppet.settings.stubs(:use)

            Puppet::SSL::CertificateAuthority.any_instance.stubs(:password?).returns true

            # Set up the CA
            @key = mock 'key'
            @key.stubs(:content).returns "cakey"
            Puppet::SSL::CertificateAuthority.any_instance.stubs(:key).returns @key
            @cacert = mock 'certificate'
            @cacert.stubs(:content).returns "cacertificate"
            @ca = Puppet::SSL::CertificateAuthority.new

            @ca.host.stubs(:certificate).returns @cacert
            @ca.host.stubs(:key).returns @key
            
            @name = "myhost"
            @real_cert = stub 'realcert', :sign => nil
            @cert = stub 'certificate', :content => @real_cert
            Puppet::SSL::Certificate.stubs(:new).returns @cert

            @cert.stubs(:content=)
            @cert.stubs(:save)

            # Stub out the factory
            @factory = stub 'factory', :result => "my real cert"
            Puppet::SSL::CertificateFactory.stubs(:new).returns @factory

            @request = stub 'request', :content => "myrequest"

            # And the inventory
            @inventory = stub 'inventory', :add => nil
            @ca.stubs(:inventory).returns @inventory
        end

        describe "and calculating the next certificate serial number" do
            before do
                @path = "/path/to/serial"
                Puppet.settings.stubs(:value).with(:serial).returns @path

                @filehandle = stub 'filehandle', :<< => @filehandle
                Puppet.settings.stubs(:readwritelock).with(:serial).yields @filehandle
            end

            it "should default to 0x0 for the first serial number" do
                @ca.next_serial.should == 0x0
            end

            it "should return the current content of the serial file" do
                FileTest.expects(:exist?).with(@path).returns true
                File.expects(:read).with(@path).returns "0002"

                @ca.next_serial.should == 2
            end
            
            it "should write the next serial number to the serial file as hex" do
                @filehandle.expects(:<<).with("0001")

                @ca.next_serial
            end

            it "should lock the serial file while writing" do
                Puppet.settings.expects(:readwritelock).with(:serial)

                @ca.next_serial
            end
        end

        describe "its own certificate" do
            before do
                @serial = 10
                @ca.stubs(:next_serial).returns @serial
            end

            it "should not look up a certificate request for the host" do
                Puppet::SSL::CertificateRequest.expects(:find).never

                @ca.sign(@name, :ca, @request)
            end

            it "should use a certificate type of :ca" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[0] == :ca
                end.returns @factory
                @ca.sign(@name, :ca, @request)
            end

            it "should pass the provided CSR as the CSR" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[1] == "myrequest"
                end.returns @factory
                @ca.sign(@name, :ca, @request)
            end

            it "should use the provided CSR's content as the issuer" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[2] == "myrequest"
                end.returns @factory
                @ca.sign(@name, :ca, @request)
            end

            it "should pass the next serial as the serial number" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[3] == @serial
                end.returns @factory
                @ca.sign(@name, :ca, @request)
            end

            it "should save the resulting certificate" do
                @cert.expects(:save)

                @ca.sign(@name, :ca, @request)
            end
        end

        describe "another host's certificate" do
            before do
                @serial = 10
                @ca.stubs(:next_serial).returns @serial

                Puppet::SSL::CertificateRequest.stubs(:find).with(@name).returns @request
                @cert.stubs :save
            end

            it "should generate a self-signed certificate if its Host instance has no certificate" do
                cert = stub 'ca_certificate', :content => "mock_cert"

                @ca.host.expects(:certificate).times(2).returns(nil).then.returns cert
                @ca.expects(:generate_ca_certificate)

                @ca.sign(@name)
            end

            it "should use a certificate type of :server" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[0] == :server
                end.returns @factory

                @ca.sign(@name)
            end

            it "should use look up a CSR for the host in the :ca_file terminus" do
                Puppet::SSL::CertificateRequest.expects(:find).with(@name).returns @request

                @ca.sign(@name)
            end

            it "should fail if no CSR can be found for the host" do
                Puppet::SSL::CertificateRequest.expects(:find).with(@name).returns nil

                lambda { @ca.sign(@name) }.should raise_error(ArgumentError)
            end

            it "should use the CA certificate as the issuer" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[2] == @cacert.content
                end.returns @factory
                @ca.sign(@name)
            end

            it "should pass the next serial as the serial number" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[3] == @serial
                end.returns @factory
                @ca.sign(@name)
            end

            it "should sign the resulting certificate using its real key and a digest" do
                digest = mock 'digest'
                OpenSSL::Digest::SHA1.expects(:new).returns digest

                key = stub 'key', :content => "real_key"
                @ca.host.stubs(:key).returns key

                @cert.content.expects(:sign).with("real_key", digest)
                @ca.sign(@name)
            end

            it "should save the resulting certificate" do
                @cert.expects(:save)
                @ca.sign(@name)
            end
        end

        it "should create a certificate instance with the content set to the newly signed x509 certificate" do
            @serial = 10
            @ca.stubs(:next_serial).returns @serial

            Puppet::SSL::CertificateRequest.stubs(:find).with(@name).returns @request
            @cert.stubs :save
            Puppet::SSL::Certificate.expects(:new).with(@name).returns @cert

            @ca.sign(@name)
        end

        it "should return the certificate instance" do
            Puppet::SSL::CertificateRequest.stubs(:find).with(@name).returns @request
            @cert.stubs :save
            @ca.sign(@name).should equal(@cert)
        end

        it "should add the certificate to its inventory" do
            @inventory.expects(:add).with(@cert)

            Puppet::SSL::CertificateRequest.stubs(:find).with(@name).returns @request
            @cert.stubs :save
            @ca.sign(@name)
        end
    end

    describe "when managing certificate clients" do
        before do
            Puppet.settings.stubs(:use)

            Puppet::SSL::CertificateAuthority.any_instance.stubs(:password?).returns true

            # Set up the CA
            @key = mock 'key'
            @key.stubs(:content).returns "cakey"
            Puppet::SSL::CertificateAuthority.any_instance.stubs(:key).returns @key
            @cacert = mock 'certificate'
            @cacert.stubs(:content).returns "cacertificate"
            Puppet::SSL::CertificateAuthority.any_instance.stubs(:certificate).returns @cacert
            @ca = Puppet::SSL::CertificateAuthority.new
        end

        describe "when revoking certificates" do
            it "should fail if the certificate revocation list is disabled"

            it "should default to OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE as the reason"

            it "should require a serial number"
        end
    end
end
