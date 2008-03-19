#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate_authority'

describe Puppet::SSL::CertificateAuthority do
    describe "when initializing" do
        it "should always set its name to the value of :certname" do
            Puppet.settings.expects(:value).with(:certname).returns "whatever"

            Puppet::SSL::CertificateAuthority.any_instance.stubs(:setup_ca)

            Puppet::SSL::CertificateAuthority.new.name.should == "whatever"
        end

        describe "a new certificate authority" do
            before do
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
                Puppet::SSL::CertificateAuthority.any_instance.expects(:sign).with(request, :ca, true).returns cert

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
end
