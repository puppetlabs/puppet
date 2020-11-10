require 'spec_helper'

require 'puppet/network/authconfig'

describe Puppet::Network::DefaultAuthProvider do
  before :each do
    allow(Puppet::FileSystem).to receive(:stat).and_return(double('stat', :ctime => :now))
    allow(Time).to receive(:now).and_return(Time.now)
  end

  describe "when initializing" do
    it "inserts default ACLs after setting initial rights" do
      expect_any_instance_of(Puppet::Network::DefaultAuthProvider).to receive(:insert_default_acl)
      Puppet::Network::DefaultAuthProvider.new
    end
  end

  describe "when defining an acl with mk_acl" do
    before :each do
      allow_any_instance_of(Puppet::Network::DefaultAuthProvider).to receive(:insert_default_acl)
      @authprovider = Puppet::Network::DefaultAuthProvider.new
    end

    it "should create a new right for each default acl" do
      @authprovider.mk_acl(:acl => '/')
      expect(@authprovider.rights['/']).to be
    end

    it "allows everyone for each default right" do
      @authprovider.mk_acl(:acl => '/')
      expect(@authprovider.rights['/']).to be_globalallow
    end

    it "accepts an argument to restrict the method" do
      @authprovider.mk_acl(:acl => '/', :method => :find)
      expect(@authprovider.rights['/'].methods).to eq([:find])
    end

    it "creates rights with authentication set to true by default" do
      @authprovider.mk_acl(:acl => '/')
      expect(@authprovider.rights['/'].authentication).to be_truthy
    end

    it "accepts an argument to set the authentication requirement" do
      @authprovider.mk_acl(:acl => '/', :authenticated => :any)
      expect(@authprovider.rights['/'].authentication).to be_falsey
    end
  end

  describe "when adding default ACLs" do
    before :each do
      allow_any_instance_of(Puppet::Network::DefaultAuthProvider).to receive(:insert_default_acl)
      @authprovider = Puppet::Network::DefaultAuthProvider.new
      allow_any_instance_of(Puppet::Network::DefaultAuthProvider).to receive(:insert_default_acl).and_call_original
    end

    Puppet::Network::DefaultAuthProvider::default_acl.each do |acl|
      it "should create a default right for #{acl[:acl]}" do
        allow(@authprovider).to receive(:mk_acl)
        expect(@authprovider).to receive(:mk_acl).with(acl)
        @authprovider.insert_default_acl
      end
    end

    it "should log at info loglevel" do
      expect(Puppet).to receive(:info).at_least(:once)
      @authprovider.insert_default_acl
    end

    it "creates an empty catch-all rule for '/' for any authentication request state" do
      allow(@authprovider).to receive(:mk_acl)

      @authprovider.insert_default_acl
      expect(@authprovider.rights['/']).to be_empty
      expect(@authprovider.rights['/'].authentication).to be_falsey
    end

    it '(CVE-2013-2275) allows report submission only for the node matching the certname by default' do
      acl = {
        :acl => "~ ^#{Puppet::Network::HTTP::MASTER_URL_PREFIX}\/v3\/report\/([^\/]+)$",
        :method => :save,
        :allow => '$1',
        :authenticated => true
      }
      allow(@authprovider).to receive(:mk_acl)
      expect(@authprovider).to receive(:mk_acl).with(acl)
      @authprovider.insert_default_acl
    end
  end

  describe "when checking authorization" do
    it "should ask for authorization to the ACL subsystem" do
      params = {
        :ip => "127.0.0.1",
        :node => "me",
        :environment => :env,
        :authenticated => true
      }

      expect_any_instance_of(Puppet::Network::Rights).to receive(:is_request_forbidden_and_why?).with(:save, "/path/to/resource", params)

      described_class.new.check_authorization(:save, "/path/to/resource", params)
    end
  end
end

describe Puppet::Network::AuthConfig do
  after :each do
    Puppet::Network::AuthConfig.authprovider_class = nil
  end

  class TestAuthProvider
    def initialize(rights=nil); end
    def check_authorization(method, path, params); end
  end

  it "instantiates authprovider_class with rights" do
    Puppet::Network::AuthConfig.authprovider_class = TestAuthProvider
    rights = Puppet::Network::Rights.new
    expect(TestAuthProvider).to receive(:new).with(rights)
    described_class.new(rights)
  end

  it "delegates authorization check to authprovider_class" do
    Puppet::Network::AuthConfig.authprovider_class = TestAuthProvider
    expect_any_instance_of(TestAuthProvider).to receive(:check_authorization).with(:save, '/path/to/resource', {})
    described_class.new.check_authorization(:save, '/path/to/resource', {})
  end

  it "uses DefaultAuthProvider by default" do
    Puppet::Network::AuthConfig.authprovider_class = nil
    expect_any_instance_of(Puppet::Network::DefaultAuthProvider).to receive(:check_authorization).with(:save, '/path/to/resource', {})
    described_class.new.check_authorization(:save, '/path/to/resource', {})
  end
end
