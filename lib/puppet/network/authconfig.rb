require 'puppet/network/rights'
require 'puppet/network/http'

module Puppet
  class ConfigurationError < Puppet::Error; end
  class Network::DefaultAuthProvider
    attr_accessor :rights

    def self.master_url_prefix
      Puppet::Network::HTTP::MASTER_URL_PREFIX
    end

    def self.ca_url_prefix
      Puppet::Network::HTTP::CA_URL_PREFIX
    end

    def self.default_acl
      [
      # Master API V3
      { :acl => "#{master_url_prefix}/v3/environments", :method => :find, :allow => '*', :authenticated => true },

      { :acl => "~ ^#{master_url_prefix}\/v3\/catalog\/([^\/]+)$", :method => :find, :allow => '$1', :authenticated => true },
      { :acl => "~ ^#{master_url_prefix}\/v3\/node\/([^\/]+)$", :method => :find, :allow => '$1', :authenticated => true },
      { :acl => "~ ^#{master_url_prefix}\/v3\/report\/([^\/]+)$", :method => :save, :allow => '$1', :authenticated => true },

      # this one will allow all file access, and thus delegate
      # to fileserver.conf
      { :acl => "#{master_url_prefix}/v3/file" },

      { :acl => "#{master_url_prefix}/v3/status", :method => [:find], :authenticated => true },

      # CA API V1
      { :acl => "#{ca_url_prefix}/v1/certificate_revocation_list/ca", :method => :find, :authenticated => true },

      # These allow `auth any`, because if you can do them anonymously you
      # should probably also be able to do them when trusted.
      { :acl => "#{ca_url_prefix}/v1/certificate/ca", :method => :find, :authenticated => :any },
      { :acl => "#{ca_url_prefix}/v1/certificate/", :method => :find, :authenticated => :any },
      { :acl => "#{ca_url_prefix}/v1/certificate_request", :method => [:find, :save], :authenticated => :any },
      ]
      end

    # Just proxy the setting methods to our rights stuff
    [:allow, :deny].each do |method|
      define_method(method) do |*args|
        @rights.send(method, *args)
      end
    end

    # force regular ACLs to be present
    def insert_default_acl
      self.class.default_acl.each do |acl|
        unless rights[acl[:acl]]
          Puppet.info "Inserting default '#{acl[:acl]}' (auth #{acl[:authenticated]}) ACL"
          mk_acl(acl)
        end
      end
      # queue an empty (ie deny all) right for every other path
      # actually this is not strictly necessary as the rights system
      # denies not explicitly allowed paths
      unless rights["/"]
        rights.newright("/").restrict_authenticated(:any)
      end
    end

    def mk_acl(acl)
      right = @rights.newright(acl[:acl])
      right.allow(acl[:allow] || "*")

      if method = acl[:method]
        method = [method] unless method.is_a?(Array)
        method.each { |m| right.restrict_method(m) }
      end
      right.restrict_authenticated(acl[:authenticated]) unless acl[:authenticated].nil?
    end

    # check whether this request is allowed in our ACL
    # raise an Puppet::Network::AuthorizedError if the request
    # is denied.
    def check_authorization(method, path, params)
      if authorization_failure_exception = @rights.is_request_forbidden_and_why?(method, path, params)
        Puppet.warning("Denying access: #{authorization_failure_exception}")
        raise authorization_failure_exception
      end
    end

    def initialize(rights=nil)
      @rights = rights || Puppet::Network::Rights.new
      insert_default_acl
    end
  end

  class Network::AuthConfig
    @@authprovider_class = nil

    def self.authprovider_class=(klass)
      @@authprovider_class = klass
    end

    def self.authprovider_class
      @@authprovider_class || Puppet::Network::DefaultAuthProvider
    end

    def initialize(rights=nil)
      @authprovider = self.class.authprovider_class.new(rights)
    end

    def check_authorization(method, path, params)
      @authprovider.check_authorization(method, path, params)
    end
  end
end
