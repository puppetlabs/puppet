require 'spec_helper'

require 'puppet/util/ldap/connection'

# So our mocks and such all work, even when ldap isn't available.
unless Puppet.features.ldap?
  class LDAP
    class Conn
      def initialize(*args)
      end
    end
    class SSLConn < Conn; end

    LDAP_OPT_PROTOCOL_VERSION = 1
    LDAP_OPT_REFERRALS = 2
    LDAP_OPT_ON = 3
  end
end

describe Puppet::Util::Ldap::Connection do
  before do
    allow(Puppet.features).to receive(:ldap?).and_return(true)

    @ldapconn = double(
      'ldap',
      set_option: nil,
      simple_bind: nil,
    )
    allow(LDAP::Conn).to receive(:new).and_return(@ldapconn)
    allow(LDAP::SSLConn).to receive(:new).and_return(@ldapconn)

    @connection = Puppet::Util::Ldap::Connection.new("host", 1234)
  end


  describe "when creating connections" do
    it "should require the host and port" do
      expect { Puppet::Util::Ldap::Connection.new("myhost") }.to raise_error(ArgumentError)
    end

    it "should allow specification of a user and password" do
      expect { Puppet::Util::Ldap::Connection.new("myhost", 1234, :user => "blah", :password => "boo") }.not_to raise_error
    end

    it "should allow specification of ssl" do
      expect { Puppet::Util::Ldap::Connection.new("myhost", 1234, :ssl => :tsl) }.not_to raise_error
    end

    it "should support requiring a new connection" do
      expect { Puppet::Util::Ldap::Connection.new("myhost", 1234, :reset => true) }.not_to raise_error
    end

    it "should fail if ldap is unavailable" do
      expect(Puppet.features).to receive(:ldap?).and_return(false)

      expect { Puppet::Util::Ldap::Connection.new("host", 1234) }.to raise_error(Puppet::Error)
    end

    it "should use neither ssl nor tls by default" do
      expect(LDAP::Conn).to receive(:new).with("host", 1234).and_return(@ldapconn)

      @connection.start
    end

    it "should use LDAP::SSLConn if ssl is requested" do
      expect(LDAP::SSLConn).to receive(:new).with("host", 1234).and_return(@ldapconn)

      @connection.ssl = true

      @connection.start
    end

    it "should use LDAP::SSLConn and tls if tls is requested" do
      expect(LDAP::SSLConn).to receive(:new).with("host", 1234, true).and_return(@ldapconn)

      @connection.ssl = :tls

      @connection.start
    end

    it "should set the protocol version to 3 and enable referrals" do
      expect(@ldapconn).to receive(:set_option).with(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
      expect(@ldapconn).to receive(:set_option).with(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_ON)
      @connection.start
    end

    it "should bind with the provided user and password" do
      @connection.user = "myuser"
      @connection.password = "mypassword"
      expect(@ldapconn).to receive(:simple_bind).with("myuser", "mypassword")

      @connection.start
    end

    it "should bind with no user and password if none has been provided" do
      expect(@ldapconn).to receive(:simple_bind).with(nil, nil)
      @connection.start
    end
  end

  describe "when closing connections" do
    it "should not close connections that are not open" do
      allow(@connection).to receive(:connection).and_return(@ldapconn)

      expect(@ldapconn).to receive(:bound?).and_return(false)
      expect(@ldapconn).not_to receive(:unbind)

      @connection.close
    end
  end

  it "should have a class-level method for creating a default connection" do
    expect(Puppet::Util::Ldap::Connection).to respond_to(:instance)
  end

  describe "when creating a default connection" do
    it "should use the :ldapserver setting to determine the host" do
      Puppet[:ldapserver] = "myserv"
      expect(Puppet::Util::Ldap::Connection).to receive(:new).with("myserv", anything, anything)
      Puppet::Util::Ldap::Connection.instance
    end

    it "should use the :ldapport setting to determine the port" do
      Puppet[:ldapport] = 456
      expect(Puppet::Util::Ldap::Connection).to receive(:new).with(anything, 456, anything)
      Puppet::Util::Ldap::Connection.instance
    end

    it "should set ssl to :tls if tls is enabled" do
      Puppet[:ldaptls] = true
      expect(Puppet::Util::Ldap::Connection).to receive(:new).with(anything, anything, hash_including(ssl: :tls))
      Puppet::Util::Ldap::Connection.instance
    end

    it "should set ssl to 'true' if ssl is enabled and tls is not" do
      Puppet[:ldaptls] = false
      Puppet[:ldapssl] = true
      expect(Puppet::Util::Ldap::Connection).to receive(:new).with(anything, anything, hash_including(ssl: true))
      Puppet::Util::Ldap::Connection.instance
    end

    it "should set ssl to false if neither ssl nor tls are enabled" do
      Puppet[:ldaptls] = false
      Puppet[:ldapssl] = false
      expect(Puppet::Util::Ldap::Connection).to receive(:new).with(anything, anything, hash_including(ssl: false))
      Puppet::Util::Ldap::Connection.instance
    end

    it "should set the ldapuser if one is set" do
      Puppet[:ldapuser] = "foo"
      expect(Puppet::Util::Ldap::Connection).to receive(:new).with(anything, anything, hash_including(user: "foo"))
      Puppet::Util::Ldap::Connection.instance
    end

    it "should set the ldapuser and ldappassword if both is set" do
      Puppet[:ldapuser] = "foo"
      Puppet[:ldappassword] = "bar"
      expect(Puppet::Util::Ldap::Connection).to receive(:new).with(anything, anything, hash_including(user: "foo", password: "bar"))
      Puppet::Util::Ldap::Connection.instance
    end
  end
end
