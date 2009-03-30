#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rights'

describe Puppet::Network::Rights do
    before do
        @right = Puppet::Network::Rights.new
    end

    [:allow, :deny, :restrict_method, :restrict_environment].each do |m|
        it "should have a #{m} method" do
            @right.should respond_to(m)
        end

        describe "when using #{m}" do
            it "should delegate to the correct acl" do
                acl = stub 'acl'
                @right.stubs(:[]).returns(acl)

                acl.expects(m).with("me")

                @right.send(m, 'thisacl', "me")
            end
        end
    end

    it "should throw an error if type can't be determined" do
        lambda { @right.newright("name") }.should raise_error
    end

    describe "when creating new namespace ACLs" do

        it "should throw an error if the ACL already exists" do
            @right.newright("[name]")

            lambda { @right.newright("[name]") }.should raise_error
        end

        it "should create a new ACL with the correct name" do
            @right.newright("[name]")

            @right["name"].key.should == :name
        end

        it "should create an ACL of type Puppet::Network::AuthStore" do
            @right.newright("[name]")

            @right["name"].should be_a_kind_of(Puppet::Network::AuthStore)
        end
    end

    describe "when creating new path ACLs" do
        it "should not throw an error if the ACL already exists" do
            @right.newright("/name")

            lambda { @right.newright("/name")}.should_not raise_error
        end

        it "should throw an error if the acl uri path is not absolute" do
            lambda { @right.newright("name")}.should raise_error
        end

        it "should create a new ACL with the correct path" do
            @right.newright("/name")

            @right["/name"].should_not be_nil
        end

        it "should create an ACL of type Puppet::Network::AuthStore" do
            @right.newright("/name")

            @right["/name"].should be_a_kind_of(Puppet::Network::AuthStore)
        end
    end

    describe "when creating new regex ACLs" do
        it "should not throw an error if the ACL already exists" do
            @right.newright("~ .rb$")

            lambda { @right.newright("~ .rb$")}.should_not raise_error
        end

        it "should create a new ACL with the correct regex" do
            @right.newright("~ .rb$")

            @right.include?(".rb$").should_not be_nil
        end

        it "should be able to lookup the regex" do
            @right.newright("~ .rb$")

            @right[".rb$"].should_not be_nil
        end

        it "should create an ACL of type Puppet::Network::AuthStore" do
            @right.newright("~ .rb$").should be_a_kind_of(Puppet::Network::AuthStore)
        end
    end

    describe "when checking ACLs existence" do
        it "should return false if there are no matching rights" do
            @right.include?("name").should be_false
        end

        it "should return true if a namespace rights exist" do
            @right.newright("[name]")

            @right.include?("name").should be_true
        end

        it "should return false if no matching namespace rights exist" do
            @right.newright("[name]")

            @right.include?("notname").should be_false
        end

        it "should return true if a path right exists" do
            @right.newright("/name")

            @right.include?("/name").should be_true
        end

        it "should return false if no matching path rights exist" do
            @right.newright("/name")

            @right.include?("/differentname").should be_false
        end

        it "should return true if a regex right exists" do
            @right.newright("~ .rb$")

            @right.include?(".rb$").should be_true
        end

        it "should return false if no matching path rights exist" do
            @right.newright("~ .rb$")

            @right.include?(".pp$").should be_false
        end
    end

    describe "when checking if right is allowed" do
        before :each do
            @right.stubs(:right).returns(nil)

            @pathacl = stub 'pathacl', :acl_type => :path
            Puppet::Network::Rights::Right.stubs(:new).returns(@pathacl)
        end

        it "should first check namespace rights" do
            acl = stub 'acl', :acl_type => :name, :key => :namespace
            Puppet::Network::Rights::Right.stubs(:new).returns(acl)

            @right.newright("[namespace]")
            acl.expects(:match?).returns(true)
            acl.expects(:allowed?).with(:args, true).returns(true)

            @right.allowed?("namespace", :args)
        end

        it "should then check for path rights if no namespace match" do
            acl = stub 'acl', :acl_type => :name, :match? => false

            acl.expects(:allowed?).with(:args).never
            @right.newright("/path/to/there")

            @pathacl.stubs(:match?).returns(true)
            @pathacl.expects(:allowed?)

            @right.allowed?("/path/to/there", :args)
        end

        it "should pass the match? return to allowed?" do
            @right.newright("/path/to/there")

            @pathacl.expects(:match?).returns(:match)
            @pathacl.expects(:allowed?).with(:args, :match)

            @right.allowed?("/path/to/there", :args)
        end

        describe "with namespace acls" do
            it "should raise an error if this namespace right doesn't exist" do
                lambda{ @right.allowed?("namespace") }.should raise_error
            end
        end

        describe "with path acls" do
            before :each do
                @long_acl = stub 'longpathacl', :name => "/path/to/there", :acl_type => :regex
                Puppet::Network::Rights::Right.stubs(:new).with("/path/to/there", 0).returns(@long_acl)

                @short_acl = stub 'shortpathacl', :name => "/path/to", :acl_type => :regex
                Puppet::Network::Rights::Right.stubs(:new).with("/path/to", 0).returns(@short_acl)

                @long_acl.stubs(:"<=>").with(@short_acl).returns(0)
                @short_acl.stubs(:"<=>").with(@long_acl).returns(0)
            end

            it "should select the first match" do
                @right.newright("/path/to/there", 0)
                @right.newright("/path/to", 0)

                @long_acl.stubs(:match?).returns(true)
                @short_acl.stubs(:match?).returns(true)

                @long_acl.expects(:allowed?).returns(true)
                @short_acl.expects(:allowed?).never

                @right.allowed?("/path/to/there/and/there", :args)
            end

            it "should select the first match that doesn't return :dunno" do
                @right.newright("/path/to/there", 0)
                @right.newright("/path/to", 0)

                @long_acl.stubs(:match?).returns(true)
                @short_acl.stubs(:match?).returns(true)

                @long_acl.expects(:allowed?).returns(:dunno)
                @short_acl.expects(:allowed?)

                @right.allowed?("/path/to/there/and/there", :args)
            end

            it "should not select an ACL that doesn't match" do
                @right.newright("/path/to/there", 0)
                @right.newright("/path/to", 0)

                @long_acl.stubs(:match?).returns(false)
                @short_acl.stubs(:match?).returns(true)

                @long_acl.expects(:allowed?).never
                @short_acl.expects(:allowed?)

                @right.allowed?("/path/to/there/and/there", :args)
            end

            it "should return the result of the acl" do
                @right.newright("/path/to/there", 0)

                @long_acl.stubs(:match?).returns(true)
                @long_acl.stubs(:allowed?).returns(:returned)

                @right.allowed?("/path/to/there/and/there", :args).should == :returned
            end

            it "should not raise an error if this path acl doesn't exist" do
                lambda{ @right.allowed?("/path", :args) }.should_not raise_error
            end

            it "should return false if no path match" do
                @right.allowed?("/path", :args).should be_false
            end
        end

        describe "with regex acls" do
            before :each do
                @regex_acl1 = stub 'regex_acl1', :name => "/files/(.*)/myfile", :acl_type => :regex
                Puppet::Network::Rights::Right.stubs(:new).with("~ /files/(.*)/myfile", 0).returns(@regex_acl1)

                @regex_acl2 = stub 'regex_acl2', :name => "/files/(.*)/myfile/", :acl_type => :regex
                Puppet::Network::Rights::Right.stubs(:new).with("~ /files/(.*)/myfile/", 0).returns(@regex_acl2)

                @regex_acl1.stubs(:"<=>").with(@regex_acl2).returns(0)
                @regex_acl2.stubs(:"<=>").with(@regex_acl1).returns(0)
            end

            it "should select the first match" do
                @right.newright("~ /files/(.*)/myfile", 0)
                @right.newright("~ /files/(.*)/myfile/", 0)

                @regex_acl1.stubs(:match?).returns(true)
                @regex_acl2.stubs(:match?).returns(true)

                @regex_acl1.expects(:allowed?).returns(true)
                @regex_acl2.expects(:allowed?).never

                @right.allowed?("/files/repository/myfile/other", :args)
            end

            it "should select the first match that doesn't return :dunno" do
                @right.newright("~ /files/(.*)/myfile", 0)
                @right.newright("~ /files/(.*)/myfile/", 0)

                @regex_acl1.stubs(:match?).returns(true)
                @regex_acl2.stubs(:match?).returns(true)

                @regex_acl1.expects(:allowed?).returns(:dunno)
                @regex_acl2.expects(:allowed?)

                @right.allowed?("/files/repository/myfile/other", :args)
            end

            it "should not select an ACL that doesn't match" do
                @right.newright("~ /files/(.*)/myfile", 0)
                @right.newright("~ /files/(.*)/myfile/", 0)

                @regex_acl1.stubs(:match?).returns(false)
                @regex_acl2.stubs(:match?).returns(true)

                @regex_acl1.expects(:allowed?).never
                @regex_acl2.expects(:allowed?)

                @right.allowed?("/files/repository/myfile/other", :args)
            end

            it "should return the result of the acl" do
                @right.newright("~ /files/(.*)/myfile", 0)

                @regex_acl1.stubs(:match?).returns(true)
                @regex_acl1.stubs(:allowed?).returns(:returned)

                @right.allowed?("/files/repository/myfile/other", :args).should == :returned
            end

            it "should not raise an error if no regex acl match" do
                lambda{ @right.allowed?("/path", :args) }.should_not raise_error
            end

            it "should return false if no regex match" do
                @right.allowed?("/path", :args).should be_false
            end

        end
    end

    describe Puppet::Network::Rights::Right do
        before :each do
            @acl = Puppet::Network::Rights::Right.new("/path",0)
        end

        describe "with path" do
            it "should say it's a regex ACL" do
                @acl.acl_type.should == :regex
            end

            it "should match up to its path length" do
                @acl.match?("/path/that/works").should_not be_nil
            end

            it "should match up to its path length" do
                @acl.match?("/paththatalsoworks").should_not be_nil
            end

            it "should return nil if no match" do
                @acl.match?("/notpath").should be_nil
            end
        end

        describe "with regex" do
            before :each do
                @acl = Puppet::Network::Rights::Right.new("~ .rb$",0)
            end

            it "should say it's a regex ACL" do
                @acl.acl_type.should == :regex
            end

            it "should match as a regex" do
                @acl.match?("this shoud work.rb").should_not be_nil
            end

            it "should return nil if no match" do
                @acl.match?("do not match").should be_nil
            end
        end

        it "should allow all rest methods by default" do
            @acl.methods.should == Puppet::Network::Rights::Right::ALL
        end

        it "should allow modification of the methods filters" do
            @acl.restrict_method(:save)

            @acl.methods.should == [:save]
        end

        it "should stack methods filters" do
            @acl.restrict_method(:save)
            @acl.restrict_method(:destroy)

            @acl.methods.should == [:save, :destroy]
        end

        it "should raise an error if the method is already filtered" do
            @acl.restrict_method(:save)

            lambda { @acl.restrict_method(:save) }.should raise_error
        end

        it "should allow setting an environment filters" do
            Puppet::Node::Environment.stubs(:new).with(:environment).returns(:env)

            @acl.restrict_environment(:environment)

            @acl.environment.should == [:env]
        end

        describe "when checking right authorization" do
            it "should return :dunno if this right is not restricted to the given method" do
                @acl.restrict_method(:destroy)

                @acl.allowed?("me","127.0.0.1", :save).should == :dunno
            end

            it "should return allow/deny if this right is restricted to the given method" do
                @acl.restrict_method(:save)
                @acl.allow("127.0.0.1")

                @acl.allowed?("me","127.0.0.1", :save).should be_true
            end

            it "should return :dunno if this right is not restricted to the given environment" do
                Puppet::Node::Environment.stubs(:new).returns(:production)

                @acl.restrict_environment(:production)

                @acl.allowed?("me","127.0.0.1", :save, :development).should == :dunno
            end

            it "should interpolate allow/deny patterns with the given match" do
                @acl.expects(:interpolate).with(:match)

                @acl.allowed?("me","127.0.0.1", :save, nil, :match)
            end

            it "should reset interpolation after the match" do
                @acl.expects(:reset_interpolation)

                @acl.allowed?("me","127.0.0.1", :save, nil, :match)
            end

            # mocha doesn't allow testing super...
            # it "should delegate to the AuthStore for the result" do
            #     @acl.method(:save)
            # 
            #     @acl.expects(:allowed?).with("me","127.0.0.1")
            # 
            #     @acl.allowed?("me","127.0.0.1", :save)
            # end
        end
    end

end
