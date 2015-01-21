require 'puppet/util/ldap'
require 'puppet/util/methodhelper'

class Puppet::Util::Ldap::Connection
  include Puppet::Util::MethodHelper

  attr_accessor :host, :port, :user, :password, :reset, :ssl, :crtdir

  attr_reader :connection

  # Return a default connection, using our default settings.
  def self.instance
    ssl = if Puppet[:ldaptls]
      :tls
        elsif Puppet[:ldapssl]
          true
        else
          false
        end

    crtdir = Puppet[:ldapcrtdir]
    
    options = {}
    options[:ssl] = ssl
    options[:crtdir] = crtdir
    if user = Puppet.settings[:ldapuser] and user != ""
      options[:user] = user
      if pass = Puppet.settings[:ldappassword] and pass != ""
        options[:password] = pass
      end
    end

    new(Puppet[:ldapserver], Puppet[:ldapport], options)
  end

  def close
    connection.unbind if connection.bound?
  end

  def initialize(host, port, options = {})
    raise Puppet::Error, "Could not set up LDAP Connection: Missing ruby/ldap libraries" unless Puppet.features.ldap?

    @host, @port = host, port

    set_options(options)
  end

  # Create a per-connection unique name.
  def name
    [host, port, user, password, ssl, crtdir].collect { |p| p.to_s }.join("/")
  end

  # Should we reset the connection?
  def reset?
    reset
  end

  # Start our ldap connection.
  def start
      case ssl
      when :tls
      if crtdir
        @connection = LDAP::SSLConn.new(host, port, true, crtdir);
      else
        @connection = LDAP::SSLConn.new(host, port, true)
      end
      when true
      if crtdir
        @connection = LDAP::SSLConn.new(host, port, true, crtdir);
      else
        @connection = LDAP::SSLConn.new(host, port)
      end
      else
        @connection = LDAP::Conn.new(host, port)
      end
      @connection.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
      @connection.set_option(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_ON)
      @connection.simple_bind(user, password)
  rescue => detail
      raise Puppet::Error, "Could not connect to LDAP: #{detail}", detail.backtrace
  end
end
