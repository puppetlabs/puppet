#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

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
                    @ca.stubs(:verify)

                    @applier = @class.new(:list, [])

                    @applier.expects(:puts).with "host1\nhost2"

                    @applier.apply(@ca)
                end
            end

            describe "and :all was provided" do
                it "should print a string containing all certificate requests and certificates" do
                    @ca.expects(:waiting?).returns %w{host1 host2}
                    @ca.expects(:list).returns %w{host3 host4}
                    @ca.stubs(:verify)
                    @ca.expects(:verify).with("host3").raises(Puppet::SSL::CertificateAuthority::CertificateVerificationError.new(23), "certificate revoked")

                    @applier = @class.new(:list, :all)

                    @applier.expects(:puts).with "host1"
                    @applier.expects(:puts).with "host2"
                    @applier.expects(:puts).with "- host3 (certificate revoked)"
                    @applier.expects(:puts).with "+ host4"

                    @applier.apply(@ca)
                end
            end

           describe "and :signed was provided" do
                it "should print a string containing all signed certificate requests and certificates" do
                    @ca.expects(:list).returns %w{host1 host2}

                    @applier = @class.new(:list, :signed)

                    @applier.apply(@ca)
                end
            end

            describe "and an array of names was provided" do
                it "should print a string of all named hosts that have a waiting request" do
                    @ca.expects(:waiting?).returns %w{host1 host2}
                    @ca.expects(:list).returns %w{host3 host4}
                    @ca.stubs(:verify)

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
