require 'puppet/util/loadedfile'
require 'puppet/network/rights'

module Puppet
  class ConfigurationError < Puppet::Error; end
  class Network::AuthConfig < Puppet::Util::LoadedFile

    extend MonitorMixin
    attr_accessor :rights

    DEFAULT_ACL = [
      { :acl => "~ ^\/catalog\/([^\/]+)$", :method => :find, :allow => '$1', :authenticated => true },
      { :acl => "~ ^\/node\/([^\/]+)$", :method => :find, :allow => '$1', :authenticated => true },
      # this one will allow all file access, and thus delegate
      # to fileserver.conf
      { :acl => "/file" },
      { :acl => "/certificate_revocation_list/ca", :method => :find, :authenticated => true },
      { :acl => "/report", :method => :save, :authenticated => true },
      # These allow `auth any`, because if you can do them anonymously you
      # should probably also be able to do them when trusted.
      { :acl => "/certificate/ca", :method => :find, :authenticated => :any },
      { :acl => "/certificate/", :method => :find, :authenticated => :any },
      { :acl => "/certificate_request", :method => [:find, :save], :authenticated => :any },
      { :acl => "/status", :method => [:find], :authenticated => true },
    ]

    # Just proxy the setting methods to our rights stuff
    [:allow, :deny].each do |method|
      define_method(method) do |*args|
        @rights.send(method, *args)
      end
    end

    def self.main
      synchronize do
        add_acl = @main.nil?
        @main ||= self.new
        @main.insert_default_acl if add_acl and !@main.exists?
      end
      @main
    end

    # force regular ACLs to be present
    def insert_default_acl
      if exists? then
        reason = "none were found in '#{@file}'"
      else
        reason = "#{Puppet[:rest_authconfig]} doesn't exist"
      end

      DEFAULT_ACL.each do |acl|
        unless rights[acl[:acl]]
          Puppet.info "Inserting default '#{acl[:acl]}' (auth #{acl[:authenticated]}) ACL because #{reason}"
          mk_acl(acl)
        end
      end
      # queue an empty (ie deny all) right for every other path
      # actually this is not strictly necessary as the rights system
      # denies not explicitely allowed paths
      unless rights["/"]
        rights.newright("/")
        rights.restrict_authenticated("/", :any)
      end
    end

    def mk_acl(acl)
      @rights.newright(acl[:acl])
      @rights.allow(acl[:acl], acl[:allow] || "*")

      if method = acl[:method]
        method = [method] unless method.is_a?(Array)
        method.each { |m| @rights.restrict_method(acl[:acl], m) }
      end
      @rights.restrict_authenticated(acl[:acl], acl[:authenticated]) unless acl[:authenticated].nil?
    end

    # Does the file exist?  Puppet master does not require it, but
    # puppet agent does.
    def exists?
      FileTest.exists?(@file)
    end

    def initialize(file = nil, parsenow = true)
      @file = file || Puppet[:rest_authconfig]

      raise Puppet::DevError, "No authconfig file defined" unless @file
      return unless self.exists?
      super(@file)
      @rights = Puppet::Network::Rights.new
      @configstamp = @configstatted = nil
      @configtimeout = 60

      read if parsenow
    end

    # check whether this request is allowed in our ACL
    # raise an Puppet::Network::AuthorizedError if the request
    # is denied.
    def check_authorization(indirection, method, key, params)
      read

      if authorization_failure_exception = @rights.is_request_forbidden_and_why?(indirection, method, key, params)
        Puppet.warning("Denying access: #{authorization_failure_exception}")
        raise authorization_failure_exception
      end
    end

    #### Methods originally on Network::Authconfig

    # Read the configuration file.
    def read
      #XXX So if you delete the file, that change is not picked up?
      return unless self.exists?

      if @configstamp
        if @configtimeout and @configstatted
          if Time.now - @configstatted > @configtimeout
            @configstatted = Time.now
            tmp = File.stat(@file).ctime

            if tmp == @configstamp
              return
            else
              Puppet.notice "#{tmp} vs #{@configstamp}"
            end
          else
            return
          end
        else
          Puppet.notice "#{@configtimeout} and #{@configstatted}"
        end
      end

      parse

      @configstamp = File.stat(@file).ctime
      @configstatted = Time.now
    end

    private

    def parse
      newrights = Puppet::Network::Rights.new
      begin
        File.open(@file) { |f|
          right = nil
          count = 1
          f.each_line { |line|
            case line
            when /^\s*#/, /^\s*$/
              # skip comments and blank lines
            when /^path\s+((?:~\s+)?[^ ]+)\s*$/ # "path /path" or "path ~ regex"
              name = $1.chomp
              right = newrights.newright(name, count, @file)
            when /^\s*(allow|deny|method|environment|auth(?:enticated)?)\s+(.+?)(\s*#.*)?$/
              parse_right_directive(right, $1, $2, count)
            else
              raise ConfigurationError, "Invalid line #{count}: #{line}"
            end
            count += 1
          }
        }
      rescue Errno::EACCES => detail
        Puppet.err "Configuration error: Cannot read #{@file}; cannot serve"
      rescue Errno::ENOENT => detail
        Puppet.err "Configuration error: '#{@file}' does not exit; cannot serve"
      end
      #TODO this should fail hard

      # Verify each of the rights are valid.
      # We let the check raise an error, so that it can raise an error
      # pointing to the specific problem.
      newrights.each { |name, right|
        right.valid?
      }
      @rights = newrights
      insert_default_acl
    end

    def parse_right_directive(right, var, value, count)
      value.strip!
      case var
      when "allow"
        modify_right(right, :allow, value, "allowing %s access", count)
      when "deny"
        modify_right(right, :deny, value, "denying %s access", count)
      when "method"
        modify_right(right, :restrict_method, value, "allowing 'method' %s", count)
      when "environment"
        modify_right(right, :restrict_environment, value, "adding environment %s", count)
      when /auth(?:enticated)?/
        modify_right(right, :restrict_authenticated, value, "adding authentication %s", count)
      else
        raise ConfigurationError,
          "Invalid argument '#{var}' at line #{count}"
      end
    end

    def modify_right(right, method, value, msg, count)
      value.split(/\s*,\s*/).each do |val|
        begin
          val.strip!
          right.info msg % val
          right.send(method, val)
        rescue AuthStoreError => detail
          raise ConfigurationError, "#{detail} at line #{count} of #{@file}"
        end
      end
    end
  end
end
