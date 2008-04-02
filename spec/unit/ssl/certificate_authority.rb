#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate_authority'

describe Puppet::SSL::CertificateAuthority do
    describe "when initializing" do
        it "should always set its name to the value of :certname" do
            Puppet.settings.stubs(:use)
            Puppet.settings.expects(:value).with(:certname).returns "whatever"

            Puppet::SSL::CertificateAuthority.any_instance.stubs(:setup_ca)

            Puppet::SSL::CertificateAuthority.new.name.should == "whatever"
        end

        it "should use the :main, :ca, and :ssl settings sections" do
            Puppet.settings.expects(:use).with(:main, :ssl, :ca)
            Puppet::SSL::CertificateAuthority.any_instance.stubs(:setup_ca)
            Puppet::SSL::CertificateAuthority.new
        end

        describe "a new certificate authority" do
            before do
                Puppet.settings.stubs(:use)
                Puppet.settings.stubs(:value).with(:certname).returns "whatever"
            end

            it "should create and store a password at :capass" do
                Puppet.settings.expects(:value).with(:capass).returns "/path/to/pass"

                FileTest.expects(:exist?).with("/path/to/pass").returns false

                fh = mock 'filehandle'
                Puppet.settings.expects(:write).with(:capass).yields fh

                fh.expects(:print).with { |s| s.length > 18 }

                [:read_key, :generate_key, :read_certificate, :generate_certificate].each do |method|
                    Puppet::SSL::CertificateAuthority.any_instance.stubs(method)
                end

                Puppet::SSL::CertificateAuthority.new
            end

            it "should create and store a key encrypted with the password at :cakey" do
                Puppet.settings.stubs(:value).with(:capass).returns "/path/to/pass"
                Puppet.settings.stubs(:value).with(:cakey).returns "/path/to/key"

                FileTest.expects(:exist?).with("/path/to/key").returns false

                key = mock 'key'

                Puppet::SSL::Key.expects(:new).with("whatever").returns key
                key.expects(:password_file=).with("/path/to/pass")
                key.expects(:generate)

                key.expects(:to_s).returns "my key"

                fh = mock 'filehandle'
                Puppet.settings.expects(:write).with(:cakey).yields fh
                fh.expects(:print).with("my key")

                [:generate_password, :read_certificate, :generate_certificate].each do |method|
                    Puppet::SSL::CertificateAuthority.any_instance.stubs(method)
                end
                Puppet::SSL::CertificateAuthority.any_instance.stubs(:password?).returns true

                Puppet::SSL::CertificateAuthority.new
            end

            it "should create, sign, and store a self-signed cert at :cacert" do
                Puppet.settings.stubs(:value).with(:cacert).returns "/path/to/cert"

                FileTest.expects(:exist?).with("/path/to/cert").returns false

                request = mock 'request'
                Puppet::SSL::CertificateRequest.expects(:new).with("whatever").returns request
                request.expects(:generate)

                cert = mock 'cert'
                cert.expects(:to_s).returns "my cert"
                Puppet::SSL::CertificateAuthority.any_instance.expects(:sign).with("whatever", :ca, request).returns cert

                fh = mock 'filehandle'
                Puppet.settings.expects(:write).with(:cacert).yields fh
                fh.expects(:print).with("my cert")

                [:password?, :generate_password, :read_key, :generate_key].each do |method|
                    Puppet::SSL::CertificateAuthority.any_instance.stubs(method)
                end

                Puppet::SSL::CertificateAuthority.new
            end
        end

        describe "an existing certificate authority" do
            it "should read and decrypt the key at :cakey using the password at :capass and it should read the cert at :cacert" do
                Puppet.settings.stubs(:value).with(:certname).returns "whatever"
                Puppet.settings.stubs(:use)

                paths = {}
                [:capass, :cakey, :cacert].each do |value|
                    paths[value] = "/path/to/#{value.to_s}"
                    Puppet.settings.stubs(:value).with(value).returns paths[value]
                    FileTest.stubs(:exist?).with(paths[value]).returns true
                end

                key = mock 'key'
                Puppet::SSL::Key.expects(:new).with("whatever").returns key
                key.expects(:password_file=).returns paths[:capass]
                key.expects(:read).returns paths[:cakey]
                key.stubs(:content).returns "mykey"

                cert = mock 'cert'
                Puppet::SSL::Certificate.expects(:new).with("whatever").returns cert
                cert.expects(:read).returns paths[:cacert]
                cert.stubs(:content).returns "mycert"

                Puppet::SSL::CertificateAuthority.new
            end
        end
    end

    describe "when signing" do
        before do
            Puppet.settings.stubs(:value).with(:certname).returns "whatever"
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
            
            # Stub out the factory
            @name = "myhost"
            @real_cert = stub 'realcert', :sign => nil
            @cert = stub 'certificate', :content => @real_cert
            Puppet::SSL::Certificate.stubs(:new).returns @cert

            @cert.stubs(:content=)

            @factory = stub 'factory', :result => "my real cert"
            Puppet::SSL::CertificateFactory.stubs(:new).returns @factory

            @request = stub 'request', :content => "myrequest"
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

            it "should not save the resulting certificate" do
                @cert.expects(:save).never
            end
        end

        describe "another host's certificate" do
            before do
                @serial = 10
                @ca.stubs(:next_serial).returns @serial

                Puppet::SSL::CertificateRequest.stubs(:find).with(@name, :in => :ca_file).returns @request
                @cert.stubs :save
            end

            it "should fail if the CA certificate cannot be found" do
                @ca.expects(:certificate).returns nil

                Puppet::SSL::CertificateRequest.stubs(:find).returns "csr"

                lambda { @ca.sign("myhost") }.should raise_error(ArgumentError)
            end

            it "should use a certificate type of :server" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[0] == :server
                end.returns @factory

                @ca.sign(@name)
            end

            it "should use look up a CSR for the host in the :ca_file terminus" do
                Puppet::SSL::CertificateRequest.expects(:find).with(@name, :in => :ca_file).returns @request

                @ca.sign(@name)
            end

            it "should fail if no CSR can be found for the host" do
                Puppet::SSL::CertificateRequest.expects(:find).with(@name, :in => :ca_file).returns nil

                lambda { @ca.sign(@name) }.should raise_error(ArgumentError)
            end

            it "should use the CA certificate as the issuer" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[2] == @cacert
                end.returns @factory
                @ca.sign(@name)
            end

            it "should pass the next serial as the serial number" do
                Puppet::SSL::CertificateFactory.expects(:new).with do |*args|
                    args[3] == @serial
                end.returns @factory
                @ca.sign(@name)
            end

            it "should sign the resulting certificate using its key and a digest" do
                digest = mock 'digest'
                OpenSSL::Digest::SHA1.expects(:new).returns digest

                key = mock 'key'
                @ca.stubs(:key).returns key

                @cert.content.expects(:sign).with(key, digest)
                @ca.sign(@name)
            end

            it "should save the resulting certificate in the :ca_file terminus" do
                @cert.expects(:save).with(:in => :ca_file)
                @ca.sign(@name)
            end
        end

        it "should create a certificate instance with the content set to the newly signed x509 certificate" do
            @serial = 10
            @ca.stubs(:next_serial).returns @serial

            Puppet::SSL::CertificateRequest.stubs(:find).with(@name, :in => :ca_file).returns @request
            @cert.stubs :save
            Puppet::SSL::Certificate.expects(:new).with(@name).returns @cert

            @ca.sign(@name)
        end

        it "should return the certificate instance" do
            @serial = 10
            @ca.stubs(:next_serial).returns @serial

            Puppet::SSL::CertificateRequest.stubs(:find).with(@name, :in => :ca_file).returns @request
            @cert.stubs :save
            @ca.sign(@name).should equal(@cert)
        end
    end

    describe "when managing certificate clients" do
        before do
            Puppet.settings.stubs(:value).with(:certname).returns "whatever"
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
