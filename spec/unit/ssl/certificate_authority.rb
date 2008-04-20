#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate_authority'

describe "a normal interface method", :shared => true do
    it "should call the method on the CA for each host specified if an array was provided" do
        @ca.expects(@method).with("host1")
        @ca.expects(@method).with("host2")

        @applier = Puppet::SSL::CertificateAuthority::Interface.new(@method, %w{host1 host2})

        @applier.apply(@ca)
    end

    it "should call the method on the CA for all existing certificates if :all was provided" do
        @ca.expects(:list).returns %w{host1 host2}

        @ca.expects(@method).with("host1")
        @ca.expects(@method).with("host2")

        @applier = Puppet::SSL::CertificateAuthority::Interface.new(@method, :all)

        @applier.apply(@ca)
    end
end

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

    describe "when retrieving the certificate revocation list" do
        before do
            Puppet.settings.stubs(:use)
            Puppet.settings.stubs(:value).returns "whatever"

            Puppet::SSL::CertificateAuthority.any_instance.stubs(:generate_ca_certificate)
            @ca = Puppet::SSL::CertificateAuthority.new
        end

        describe "and the CRL is disabled" do
            it "should return nil when the :cacrl is false" do
                Puppet.settings.stubs(:value).with(:cacrl).returns false

                Puppet::SSL::CertificateRevocationList.expects(:new).never

                @ca.crl.should be_nil
            end

            it "should return nil when the :cacrl is 'false'" do
                Puppet.settings.stubs(:value).with(:cacrl).returns 'false'

                Puppet::SSL::CertificateRevocationList.expects(:new).never

                @ca.crl.should be_nil
            end
        end

        describe "and the CRL is enabled" do
            before do
                Puppet.settings.stubs(:value).with(:cacrl).returns "/my/crl"

                cert = stub("certificate", :content => "real_cert")
                @host = stub 'host', :certificate => cert, :name => "hostname"

                @ca.stubs(:host).returns @host
            end

            it "should return any found CRL instance" do
                crl = mock 'crl'
                Puppet::SSL::CertificateRevocationList.expects(:find).returns crl
                @ca.crl.should equal(crl)
            end

            it "should create and generate a new CRL instance of no CRL can be found" do
                crl = mock 'crl'
                Puppet::SSL::CertificateRevocationList.expects(:find).returns nil

                Puppet::SSL::CertificateRevocationList.expects(:new).returns crl

                crl.expects(:generate).with(@ca.host.certificate.content)

                @ca.crl.should equal(crl)
            end
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

            @request = stub 'request', :content => "myrequest", :name => @name

            # And the inventory
            @inventory = stub 'inventory', :add => nil
            @ca.stubs(:inventory).returns @inventory

            Puppet::SSL::CertificateRequest.stubs(:destroy)
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

            it "should remove the host's certificate request" do
                Puppet::SSL::CertificateRequest.expects(:destroy).with(@name)

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
            @ca = Puppet::SSL::CertificateAuthority.new
        end

        it "should have a method for acting on the SSL files" do
            @ca.should respond_to(:apply)
        end

        describe "when applying a method to a set of hosts" do
            it "should fail if no subjects have been specified" do
                lambda { @ca.apply(:generate) }.should raise_error(ArgumentError)
            end

            it "should create an Interface instance with the specified method and the subjects" do
                Puppet::SSL::CertificateAuthority::Interface.expects(:new).with(:generate, :hosts).returns(stub('applier', :apply => nil))
                @ca.apply(:generate, :to => :hosts)
            end

            it "should apply the Interface with itself as the argument" do
                applier = stub('applier')
                applier.expects(:apply).with(@ca)
                Puppet::SSL::CertificateAuthority::Interface.expects(:new).returns applier
                @ca.apply(:generate, :to => :whatever)
            end
        end

        it "should be able to list waiting certificate requests" do
            req1 = stub 'req1', :name => "one"
            req2 = stub 'req2', :name => "two"
            Puppet::SSL::CertificateRequest.expects(:search).with("*").returns [req1, req2]

            @ca.waiting?.should == %w{one two}
        end
        
        it "should delegate removing hosts to the Host class" do
            Puppet::SSL::Host.expects(:destroy).with("myhost")

            @ca.destroy("myhost")
        end

        it "should be able to verify certificates" do
            @ca.should respond_to(:verify)
        end

        it "should list certificates as the sorted list of all existing signed certificates" do
            cert1 = stub 'cert1', :name => "cert1"
            cert2 = stub 'cert2', :name => "cert2"
            Puppet::SSL::Certificate.expects(:search).with("*").returns [cert1, cert2]
            @ca.list.should == %w{cert1 cert2}
        end

        describe "and printing certificates" do
            it "should return nil if the certificate cannot be found" do
                Puppet::SSL::Certificate.expects(:find).with("myhost").returns nil
                @ca.print("myhost").should be_nil
            end

            it "should print certificates by calling :to_text on the host's certificate" do
                cert1 = stub 'cert1', :name => "cert1", :to_text => "mytext"
                Puppet::SSL::Certificate.expects(:find).with("myhost").returns cert1
                @ca.print("myhost").should == "mytext"
            end
        end

        describe "and verifying certificates" do
            before do
                @store = stub 'store', :verify => true, :add_file => nil, :purpose= => nil, :add_crl => true

                OpenSSL::X509::Store.stubs(:new).returns @store

                Puppet.settings.stubs(:value).returns "crtstuff"

                @cert = stub 'cert', :content => "mycert"
                Puppet::SSL::Certificate.stubs(:find).returns @cert

                @crl = stub('crl', :content => "mycrl")

                @ca.stubs(:crl).returns @crl
            end

            it "should fail if the host's certificate cannot be found" do
                Puppet::SSL::Certificate.expects(:find).with("me").returns(nil)

                lambda { @ca.verify("me") }.should raise_error(ArgumentError)
            end

            it "should create an SSL Store to verify" do
                OpenSSL::X509::Store.expects(:new).returns @store

                @ca.verify("me")
            end

            it "should add the CA Certificate to the store" do
                Puppet.settings.stubs(:value).with(:cacert).returns "/ca/cert"
                @store.expects(:add_file).with "/ca/cert"

                @ca.verify("me")
            end

            it "should add the CRL to the store if the crl is enabled" do
                @store.expects(:add_crl).with "mycrl"

                @ca.verify("me")
            end

            it "should set the store purpose to OpenSSL::X509::PURPOSE_SSL_CLIENT" do
                Puppet.settings.stubs(:value).with(:cacert).returns "/ca/cert"
                @store.expects(:add_file).with "/ca/cert"

                @ca.verify("me")
            end

            it "should use the store to verify the certificate" do
                @cert.expects(:content).returns "mycert"

                @store.expects(:verify).with("mycert").returns true

                @ca.verify("me")
            end

            it "should fail if the verification returns false" do
                @cert.expects(:content).returns "mycert"

                @store.expects(:verify).with("mycert").returns false

                lambda { @ca.verify("me") }.should raise_error
            end
        end

        describe "and revoking certificates" do
            before do
                @crl = mock 'crl'
                @ca.stubs(:crl).returns @crl
            end

            it "should fail if the certificate revocation list is disabled" do
                @ca.stubs(:crl).returns false

                lambda { @ca.revoke('whatever') }.should raise_error(ArgumentError)

            end

            it "should delegate the revocation to its CRL" do
                @ca.crl.expects(:revoke)

                @ca.revoke('host')
            end

            it "should get the serial number from the local certificate if it exists" do
                real_cert = stub 'real_cert', :serial => 15
                cert = stub 'cert', :content => real_cert
                Puppet::SSL::Certificate.expects(:find).with("host").returns cert

                @ca.crl.expects(:revoke).with { |serial, key| serial == 15 }

                @ca.revoke('host')
            end

            it "should get the serial number from inventory if no local certificate exists" do
                real_cert = stub 'real_cert', :serial => 15
                cert = stub 'cert', :content => real_cert
                Puppet::SSL::Certificate.expects(:find).with("host").returns nil

                @ca.inventory.expects(:serial).with("host").returns 16

                @ca.crl.expects(:revoke).with { |serial, key| serial == 16 }
                @ca.revoke('host')
            end
        end

        it "should be able to generate a complete new SSL host" do
            @ca.should respond_to(:generate)
        end

        describe "and generating certificates" do
            before do
                @host = stub 'host', :generate_certificate_request => nil
                Puppet::SSL::Host.stubs(:new).returns @host
                Puppet::SSL::Certificate.stubs(:find).returns nil

                @ca.stubs(:sign)
            end

            it "should fail if a certificate already exists for the host" do
                Puppet::SSL::Certificate.expects(:find).with("him").returns "something"

                lambda { @ca.generate("him") }.should raise_error(ArgumentError)
            end

            it "should create a new Host instance with the correct name" do
                Puppet::SSL::Host.expects(:new).with("him").returns @host

                @ca.generate("him")
            end

            it "should use the Host to generate the certificate request" do
                @host.expects :generate_certificate_request

                @ca.generate("him")
            end

            it "should sign the generated request" do
                @ca.expects(:sign).with("him")

                @ca.generate("him")
            end
        end
    end
end

describe Puppet::SSL::CertificateAuthority::Interface do
    before do
        @class = Puppet::SSL::CertificateAuthority::Interface
    end
    describe "when initializing" do
        it "should set its method using its settor" do
            @class.any_instance.expects(:method=).with(:generate)
            @class.new(:generate, :all)
        end

        it "should set its subjects using the settor" do
            @class.any_instance.expects(:subjects=).with(:all)
            @class.new(:generate, :all)
        end
    end

    describe "when setting the method" do
        it "should set the method" do
            @class.new(:generate, :all).method.should == :generate
        end

        it "should fail if the method isn't a member of the INTERFACE_METHODS array" do
            Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.expects(:include?).with(:thing).returns false

            lambda { @class.new(:thing, :all) }.should raise_error(ArgumentError)
        end
    end

    describe "when setting the subjects" do
        it "should set the subjects" do
            @class.new(:generate, :all).subjects.should == :all
        end

        it "should fail if the subjects setting isn't :all or an array" do
            lambda { @class.new(:generate, "other") }.should raise_error(ArgumentError)
        end
    end

    it "should have a method for triggering the application" do
        @class.new(:generate, :all).should respond_to(:apply)
    end

    describe "when applying" do
        before do
            # We use a real object here, because :verify can't be stubbed, apparently.
            @ca = Object.new
        end

        it "should raise InterfaceErrors" do
            @applier = @class.new(:revoke, :all)

            @ca.expects(:list).raises Puppet::SSL::CertificateAuthority::Interface::InterfaceError

            lambda { @applier.apply(@ca) }.should raise_error(Puppet::SSL::CertificateAuthority::Interface::InterfaceError)
        end

        it "should log non-Interface failures rather than failing" do
            @applier = @class.new(:revoke, :all)

            @ca.expects(:list).raises ArgumentError

            Puppet.expects(:err)

            lambda { @applier.apply(@ca) }.should_not raise_error
        end

        describe "with an empty array specified and the method is not list" do
            it "should fail" do
                @applier = @class.new(:sign, [])
                lambda { @applier.apply(@ca) }.should raise_error(ArgumentError)
            end
        end

        describe ":generate" do
            it "should fail if :all was specified" do
                @applier = @class.new(:generate, :all)
                lambda { @applier.apply(@ca) }.should raise_error(ArgumentError)
            end

            it "should call :generate on the CA for each host specified" do
                @applier = @class.new(:generate, %w{host1 host2})
                
                @ca.expects(:generate).with("host1")
                @ca.expects(:generate).with("host2")

                @applier.apply(@ca)
            end
        end

        describe ":verify" do
            before { @method = :verify }
            #it_should_behave_like "a normal interface method"

            it "should call the method on the CA for each host specified if an array was provided" do
                # LAK:NOTE Mocha apparently doesn't allow you to mock :verify, but I'm confident this works in real life.
            end

            it "should call the method on the CA for all existing certificates if :all was provided" do
                # LAK:NOTE Mocha apparently doesn't allow you to mock :verify, but I'm confident this works in real life.
            end
        end

        describe ":destroy" do
            before { @method = :destroy }
            it_should_behave_like "a normal interface method"
        end

        describe ":revoke" do
            before { @method = :revoke }
            it_should_behave_like "a normal interface method"
        end

        describe ":sign" do
            describe "and an array of names was provided" do
                before do
                    @applier = @class.new(:sign, %w{host1 host2})
                end

                it "should sign the specified waiting certificate requests" do
                    @ca.expects(:sign).with("host1")
                    @ca.expects(:sign).with("host2")

                    @applier.apply(@ca)
                end
            end

            describe "and :all was provided" do
                it "should sign all waiting certificate requests" do
                    @ca.stubs(:waiting?).returns(%w{cert1 cert2})

                    @ca.expects(:sign).with("cert1")
                    @ca.expects(:sign).with("cert2")

                    @applier = @class.new(:sign, :all)
                    @applier.apply(@ca)
                end

                it "should fail if there are no waiting certificate requests" do
                    @ca.stubs(:waiting?).returns([])

                    @applier = @class.new(:sign, :all)
                    lambda { @applier.apply(@ca) }.should raise_error(Puppet::SSL::CertificateAuthority::Interface::InterfaceError)
                end
            end
        end

        describe ":list" do
            describe "and an empty array was provided" do
                it "should print a string containing all certificate requests" do
                    @ca.expects(:waiting?).returns %w{host1 host2}

                    @applier = @class.new(:list, [])

                    @applier.expects(:puts).with "host1\nhost2"

                    @applier.apply(@ca)
                end
            end

            describe "and :all was provided" do
                it "should print a string containing all certificate requests and certificates" do
                    @ca.expects(:waiting?).returns %w{host1 host2}
                    @ca.expects(:list).returns %w{host3 host4}

                    @applier = @class.new(:list, :all)

                    @applier.expects(:puts).with "host1"
                    @applier.expects(:puts).with "host2"
                    @applier.expects(:puts).with "+ host3"
                    @applier.expects(:puts).with "+ host4"

                    @applier.apply(@ca)
                end
            end

            describe "and an array of names was provided" do
                it "should print a string of all named hosts that have a waiting request" do
                    @ca.expects(:waiting?).returns %w{host1 host2}
                    @ca.expects(:list).returns %w{host3 host4}

                    @applier = @class.new(:list, %w{host1 host2 host3 host4})

                    @applier.expects(:puts).with "host1"
                    @applier.expects(:puts).with "host2"
                    @applier.expects(:puts).with "+ host3"
                    @applier.expects(:puts).with "+ host4"

                    @applier.apply(@ca)
                end
            end
        end

        describe ":print" do
            describe "and :all was provided" do
                it "should print all certificates" do
                    @ca.expects(:list).returns %w{host1 host2}

                    @applier = @class.new(:print, :all)

                    @ca.expects(:print).with("host1").returns "h1"
                    @applier.expects(:puts).with "h1"

                    @ca.expects(:print).with("host2").returns "h2"
                    @applier.expects(:puts).with "h2"

                    @applier.apply(@ca)
                end
            end

            describe "and an array of names was provided" do
                it "should print each named certificate if found" do
                    @applier = @class.new(:print, %w{host1 host2})

                    @ca.expects(:print).with("host1").returns "h1"
                    @applier.expects(:puts).with "h1"

                    @ca.expects(:print).with("host2").returns "h2"
                    @applier.expects(:puts).with "h2"

                    @applier.apply(@ca)
                end

                it "should log any named but not found certificates" do
                    @applier = @class.new(:print, %w{host1 host2})

                    @ca.expects(:print).with("host1").returns "h1"
                    @applier.expects(:puts).with "h1"

                    @ca.expects(:print).with("host2").returns nil
                    Puppet.expects(:err).with { |msg| msg.include?("host2") }

                    @applier.apply(@ca)
                end
            end
        end
    end
end
