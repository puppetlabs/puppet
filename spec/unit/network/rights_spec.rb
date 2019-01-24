require 'spec_helper'

require 'puppet/network/rights'

describe Puppet::Network::Rights do
  before do
    @right = Puppet::Network::Rights.new
  end

  describe "when validating a :head request" do
    [:find, :save].each do |allowed_method|
      it "should allow the request if only #{allowed_method} is allowed" do
        rights = Puppet::Network::Rights.new
        right = rights.newright("/")
        right.allow("*")
        right.restrict_method(allowed_method)
        right.restrict_authenticated(:any)
        expect(rights.is_request_forbidden_and_why?(:head, "/indirection_name/key", {})).to eq(nil)
      end
    end

    it "should disallow the request if neither :find nor :save is allowed" do
      rights = Puppet::Network::Rights.new
      why_forbidden = rights.is_request_forbidden_and_why?(:head, "/indirection_name/key", {})
      expect(why_forbidden).to be_instance_of(Puppet::Network::AuthorizationError)
      expect(why_forbidden.to_s).to eq("Forbidden request: /indirection_name/key [find]")
    end
  end

  it "should throw an error if type can't be determined" do
    expect { @right.newright("name") }.to raise_error(ArgumentError, /Unknown right type/)
  end

  describe "when creating new path ACLs" do
    it "should not throw an error if the ACL already exists" do
      @right.newright("/name")

      expect { @right.newright("/name")}.not_to raise_error
    end

    it "should throw an error if the acl uri path is not absolute" do
      expect { @right.newright("name")}.to raise_error(ArgumentError, /Unknown right type/)
    end

    it "should create a new ACL with the correct path" do
      @right.newright("/name")

      expect(@right["/name"]).not_to be_nil
    end

    it "should create an ACL of type Puppet::Network::AuthStore" do
      @right.newright("/name")

      expect(@right["/name"]).to be_a_kind_of(Puppet::Network::AuthStore)
    end
  end

  describe "when creating new regex ACLs" do
    it "should not throw an error if the ACL already exists" do
      @right.newright("~ .rb$")

      expect { @right.newright("~ .rb$")}.not_to raise_error
    end

    it "should create a new ACL with the correct regex" do
      @right.newright("~ .rb$")

      expect(@right.include?(".rb$")).not_to be_nil
    end

    it "should be able to lookup the regex" do
      @right.newright("~ .rb$")

      expect(@right[".rb$"]).not_to be_nil
    end

    it "should be able to lookup the regex by its full name" do
      @right.newright("~ .rb$")

      expect(@right["~ .rb$"]).not_to be_nil
    end

    it "should create an ACL of type Puppet::Network::AuthStore" do
      expect(@right.newright("~ .rb$")).to be_a_kind_of(Puppet::Network::AuthStore)
    end
  end

  describe "when checking ACLs existence" do
    it "should return false if there are no matching rights" do
      expect(@right.include?("name")).to be_falsey
    end

    it "should return true if a path right exists" do
      @right.newright("/name")

      expect(@right.include?("/name")).to be_truthy
    end

    it "should return false if no matching path rights exist" do
      @right.newright("/name")

      expect(@right.include?("/differentname")).to be_falsey
    end

    it "should return true if a regex right exists" do
      @right.newright("~ .rb$")

      expect(@right.include?(".rb$")).to be_truthy
    end

    it "should return false if no matching path rights exist" do
      @right.newright("~ .rb$")

      expect(@right.include?(".pp$")).to be_falsey
    end
  end

  describe "when checking if right is allowed" do
    before :each do
      allow(@right).to receive(:right).and_return(nil)

      @pathacl = double('pathacl', :"<=>" => 1, :line => 0, :file => 'dummy')
      allow(Puppet::Network::Rights::Right).to receive(:new).and_return(@pathacl)
    end

    it "should delegate to is_forbidden_and_why?" do
      expect(@right).to receive(:is_forbidden_and_why?).with("namespace", :node => "host.domain.com", :ip => "127.0.0.1").and_return(nil)

      @right.allowed?("namespace", "host.domain.com", "127.0.0.1")
    end

    it "should return true if is_forbidden_and_why? returns nil" do
      allow(@right).to receive(:is_forbidden_and_why?).and_return(nil)
      expect(@right.allowed?("namespace", :args)).to be_truthy
    end

    it "should return false if is_forbidden_and_why? returns an AuthorizationError" do
      allow(@right).to receive(:is_forbidden_and_why?).and_return(Puppet::Network::AuthorizationError.new("forbidden"))
      expect(@right.allowed?("namespace", :args1, :args2)).to be_falsey
    end

    it "should pass the match? return to allowed?" do
      @right.newright("/path/to/there")

      expect(@pathacl).to receive(:match?).and_return(:match)
      expect(@pathacl).to receive(:allowed?).with(anything, anything, hash_including(match: :match)).and_return(true)

      expect(@right.is_forbidden_and_why?("/path/to/there", {})).to eq(nil)
    end

    describe "with path acls" do
      before :each do
        @long_acl = double('longpathacl', :name => "/path/to/there", :line => 0, :file => 'dummy')
        allow(Puppet::Network::Rights::Right).to receive(:new).with("/path/to/there", 0, nil).and_return(@long_acl)

        @short_acl = double('shortpathacl', :name => "/path/to", :line => 0, :file => 'dummy')
        allow(Puppet::Network::Rights::Right).to receive(:new).with("/path/to", 0, nil).and_return(@short_acl)

        allow(@long_acl).to receive(:"<=>").with(@short_acl).and_return(0)
        allow(@short_acl).to receive(:"<=>").with(@long_acl).and_return(0)
      end

      it "should select the first match" do
        @right.newright("/path/to", 0)
        @right.newright("/path/to/there", 0)

        allow(@long_acl).to receive(:match?).and_return(true)
        allow(@short_acl).to receive(:match?).and_return(true)

        expect(@short_acl).to receive(:allowed?).and_return(true)
        expect(@long_acl).not_to receive(:allowed?)

        expect(@right.is_forbidden_and_why?("/path/to/there/and/there", {})).to eq(nil)
      end

      it "should select the first match that doesn't return :dunno" do
        @right.newright("/path/to/there", 0, nil)
        @right.newright("/path/to", 0, nil)

        allow(@long_acl).to receive(:match?).and_return(true)
        allow(@short_acl).to receive(:match?).and_return(true)

        expect(@long_acl).to receive(:allowed?).and_return(:dunno)
        expect(@short_acl).to receive(:allowed?).and_return(true)

        expect(@right.is_forbidden_and_why?("/path/to/there/and/there", {})).to eq(nil)
      end

      it "should not select an ACL that doesn't match" do
        @right.newright("/path/to/there", 0)
        @right.newright("/path/to", 0)

        allow(@long_acl).to receive(:match?).and_return(false)
        allow(@short_acl).to receive(:match?).and_return(true)

        expect(@long_acl).not_to receive(:allowed?)
        expect(@short_acl).to receive(:allowed?).and_return(true)

        expect(@right.is_forbidden_and_why?("/path/to/there/and/there", {})).to eq(nil)
      end

      it "should not raise an AuthorizationError if allowed" do
        @right.newright("/path/to/there", 0)

        allow(@long_acl).to receive(:match?).and_return(true)
        allow(@long_acl).to receive(:allowed?).and_return(true)

        expect(@right.is_forbidden_and_why?("/path/to/there/and/there", {})).to eq(nil)
      end

      it "should raise an AuthorizationError if the match is denied" do
        @right.newright("/path/to/there", 0, nil)

        allow(@long_acl).to receive(:match?).and_return(true)
        allow(@long_acl).to receive(:allowed?).and_return(false)

        expect(@right.is_forbidden_and_why?("/path/to/there", {})).to be_instance_of(Puppet::Network::AuthorizationError)
      end

      it "should raise an AuthorizationError if no path match" do
        expect(@right.is_forbidden_and_why?("/nomatch", {})).to be_instance_of(Puppet::Network::AuthorizationError)
      end
    end

    describe "with regex acls" do
      before :each do
        @regex_acl1 = double('regex_acl1', :name => "/files/(.*)/myfile", :line => 0, :file => 'dummy')
        allow(Puppet::Network::Rights::Right).to receive(:new).with("~ /files/(.*)/myfile", 0, nil).and_return(@regex_acl1)

        @regex_acl2 = double('regex_acl2', :name => "/files/(.*)/myfile/", :line => 0, :file => 'dummy')
        allow(Puppet::Network::Rights::Right).to receive(:new).with("~ /files/(.*)/myfile/", 0, nil).and_return(@regex_acl2)

        allow(@regex_acl1).to receive(:"<=>").with(@regex_acl2).and_return(0)
        allow(@regex_acl2).to receive(:"<=>").with(@regex_acl1).and_return(0)
      end

      it "should select the first match" do
        @right.newright("~ /files/(.*)/myfile", 0)
        @right.newright("~ /files/(.*)/myfile/", 0)

        allow(@regex_acl1).to receive(:match?).and_return(true)
        allow(@regex_acl2).to receive(:match?).and_return(true)

        expect(@regex_acl1).to receive(:allowed?).and_return(true)
        expect(@regex_acl2).not_to receive(:allowed?)

        expect(@right.is_forbidden_and_why?("/files/repository/myfile/other", {})).to eq(nil)
      end

      it "should select the first match that doesn't return :dunno" do
        @right.newright("~ /files/(.*)/myfile", 0)
        @right.newright("~ /files/(.*)/myfile/", 0)

        allow(@regex_acl1).to receive(:match?).and_return(true)
        allow(@regex_acl2).to receive(:match?).and_return(true)

        expect(@regex_acl1).to receive(:allowed?).and_return(:dunno)
        expect(@regex_acl2).to receive(:allowed?).and_return(true)

        expect(@right.is_forbidden_and_why?("/files/repository/myfile/other", {})).to eq(nil)
      end

      it "should not select an ACL that doesn't match" do
        @right.newright("~ /files/(.*)/myfile", 0)
        @right.newright("~ /files/(.*)/myfile/", 0)

        allow(@regex_acl1).to receive(:match?).and_return(false)
        allow(@regex_acl2).to receive(:match?).and_return(true)

        expect(@regex_acl1).not_to receive(:allowed?)
        expect(@regex_acl2).to receive(:allowed?).and_return(true)

        expect(@right.is_forbidden_and_why?("/files/repository/myfile/other", {})).to eq(nil)
      end

      it "should not raise an AuthorizationError if allowed" do
        @right.newright("~ /files/(.*)/myfile", 0)

        allow(@regex_acl1).to receive(:match?).and_return(true)
        allow(@regex_acl1).to receive(:allowed?).and_return(true)

        expect(@right.is_forbidden_and_why?("/files/repository/myfile/other", {})).to eq(nil)
      end

      it "should raise an error if no regex acl match" do
        expect(@right.is_forbidden_and_why?("/path", {})).to be_instance_of(Puppet::Network::AuthorizationError)
      end

      it "should raise an AuthorizedError on deny" do
        expect(@right.is_forbidden_and_why?("/path", {})).to be_instance_of(Puppet::Network::AuthorizationError)
      end

    end
  end

  describe Puppet::Network::Rights::Right do
    before :each do
      @acl = Puppet::Network::Rights::Right.new("/path",0, nil)
    end

    describe "with path" do
      it "should match up to its path length" do
        expect(@acl.match?("/path/that/works")).not_to be_nil
      end

      it "should match up to its path length" do
        expect(@acl.match?("/paththatalsoworks")).not_to be_nil
      end

      it "should return nil if no match" do
        expect(@acl.match?("/notpath")).to be_nil
      end
    end

    describe "with regex" do
      before :each do
        @acl = Puppet::Network::Rights::Right.new("~ .rb$",0, nil)
      end

      it "should match as a regex" do
        expect(@acl.match?("this should work.rb")).not_to be_nil
      end

      it "should return nil if no match" do
        expect(@acl.match?("do not match")).to be_nil
      end
    end

    it "should allow all rest methods by default" do
      expect(@acl.methods).to eq(Puppet::Network::Rights::Right::ALL)
    end

    it "should allow only authenticated request by default" do
      expect(@acl.authentication).to be_truthy
    end

    it "should allow modification of the methods filters" do
      @acl.restrict_method(:save)

      expect(@acl.methods).to eq([:save])
    end

    it "should stack methods filters" do
      @acl.restrict_method(:save)
      @acl.restrict_method(:destroy)

      expect(@acl.methods).to eq([:save, :destroy])
    end

    it "should raise an error if the method is already filtered" do
      @acl.restrict_method(:save)

      expect { @acl.restrict_method(:save) }.to raise_error(ArgumentError, /'save' is already in the '\/path'/)
    end

    it "should allow setting an environment filters" do
      env = Puppet::Node::Environment.create(:acltest, [])
      Puppet.override(:environments => Puppet::Environments::Static.new(env)) do
        @acl.restrict_environment(:acltest)

        expect(@acl.environment).to eq([env])
      end
    end

    ["on", "yes", "true", true].each do |auth|
      it "should allow filtering on authenticated requests with '#{auth}'" do
        @acl.restrict_authenticated(auth)

        expect(@acl.authentication).to be_truthy
      end
    end

    ["off", "no", "false", false, "all", "any", :all, :any].each do |auth|
      it "should allow filtering on authenticated or unauthenticated requests with '#{auth}'" do
        @acl.restrict_authenticated(auth)
        expect(@acl.authentication).to be_falsey
      end
    end

    describe "when checking right authorization" do
      it "should return :dunno if this right is not restricted to the given method" do
        @acl.restrict_method(:destroy)

        expect(@acl.allowed?("me","127.0.0.1", { :method => :save } )).to eq(:dunno)
      end

      it "should return true if this right is restricted to the given method" do
        @acl.restrict_method(:save)
        @acl.allow("me")

        expect(@acl.allowed?("me","127.0.0.1", { :method => :save, :authenticated => true })).to eq true
      end

      it "should return :dunno if this right is not restricted to the given environment" do
        prod = Puppet::Node::Environment.create(:production, [])
        dev = Puppet::Node::Environment.create(:development, [])
        Puppet.override(:environments => Puppet::Environments::Static.new(prod, dev)) do
          @acl.restrict_environment(:production)

          expect(@acl.allowed?("me","127.0.0.1", { :method => :save, :environment => dev })).to eq(:dunno)
        end
      end

      it "returns true if the request is permitted for this environment" do
        @acl.allow("me")
        prod = Puppet::Node::Environment.create(:production, [])
        Puppet.override(:environments => Puppet::Environments::Static.new(prod)) do
          @acl.restrict_environment(:production)
          expect(@acl.allowed?("me", "127.0.0.1", { :method => :save, :authenticated => true, :environment => prod })).to eq true
        end
      end

      it "should return :dunno if this right is not restricted to the given request authentication state" do
        @acl.restrict_authenticated(true)

        expect(@acl.allowed?("me","127.0.0.1", { :method => :save, :authenticated => false })).to eq(:dunno)
      end

      it "returns true if this right is restricted to the given request authentication state" do
        @acl.restrict_authenticated(false)
        @acl.allow("me")

        expect(@acl.allowed?("me","127.0.0.1", {:method => :save, :authenticated => false })).to eq true
      end

      it "should interpolate allow/deny patterns with the given match" do
        expect(@acl).to receive(:interpolate).with(:match)

        @acl.allowed?("me","127.0.0.1", { :method => :save, :match => :match, :authenticated => true })
      end

      it "should reset interpolation after the match" do
        expect(@acl).to receive(:reset_interpolation)

        @acl.allowed?("me","127.0.0.1", { :method => :save, :match => :match, :authenticated => true })
      end
    end
  end
end
