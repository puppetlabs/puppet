require 'puppet/network/rights'

module Puppet
  class ConfigurationError < Puppet::Error; end
  class Network::AuthConfig
    attr_accessor :rights

    DEFAULT_ACL = [
      { :acl => "~ ^\/catalog\/([^\/]+)$", :method => :find, :allow => '$1', :authenticated => true },
      { :acl => "~ ^\/node\/([^\/]+)$", :method => :find, :allow => '$1', :authenticated => true },
      # this one will allow all file access, and thus delegate
      # to fileserver.conf
      { :acl => "/file" },
      { :acl => "/certificate_revocation_list/ca", :method => :find, :authenticated => true },
      { :acl => "~ ^\/report\/([^\/]+)$", :method => :save, :allow => '$1', :authenticated => true },
      # These allow `auth any`, because if you can do them anonymously you
      # should probably also be able to do them when trusted.
      { :acl => "/certificate/ca", :method => :find, :authenticated => :any },
      { :acl => "/certificate/", :method => :find, :authenticated => :any },
      { :acl => "/certificate_request", :method => [:find, :save], :authenticated => :any },
      { :acl => "/status", :method => [:find], :authenticated => true },

      # API V2.0
      { :acl => "/v2.0/environments", :method => :find, :allow => '*', :authenticated => true },
    ]

    # Just proxy the setting methods to our rights stuff
    [:allow, :deny].each do |method|
      define_method(method) do |*args|
        @rights.send(method, *args)
      end
    end

    # force regular ACLs to be present
    def insert_default_acl
      DEFAULT_ACL.each do |acl|
        unless rights[acl[:acl]]
          Puppet.info "Inserting default '#{acl[:acl]}' (auth #{acl[:authenticated]}) ACL"
          mk_acl(acl)
        end
      end
      # queue an empty (ie deny all) right for every other path
      # actually this is not strictly necessary as the rights system
      # denies not explicitely allowed paths
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
end
