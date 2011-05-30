require 'puppet/util/loadedfile'
require 'puppet/network/rights'

module Puppet
  class ConfigurationError < Puppet::Error; end
  class Network::AuthConfig < Puppet::Util::LoadedFile

    def self.main
      @main ||= self.new
    end

    # Just proxy the setting methods to our rights stuff
    [:allow, :deny].each do |method|
      define_method(method) do |*args|
        @rights.send(method, *args)
      end
    end

    # Here we add a little bit of semantics.  They can set auth on a whole
    # namespace or on just a single method in the namespace.
    def allowed?(request)
      name        = request.call.intern
      namespace   = request.handler.intern
      method      = request.method.intern

      read

      if @rights.include?(name)
        return @rights[name].allowed?(request.name, request.ip)
      elsif @rights.include?(namespace)
        return @rights[namespace].allowed?(request.name, request.ip)
      end
      false
    end

    # Does the file exist?  Puppetmasterd does not require it, but
    # puppet agent does.
    def exists?
      FileTest.exists?(@file)
    end

    def initialize(file = nil, parsenow = true)
      @file = file || Puppet[:authconfig]

      raise Puppet::DevError, "No authconfig file defined" unless @file
      return unless self.exists?
      super(@file)
      @rights = Puppet::Network::Rights.new
      @configstamp = @configstatted = nil
      @configtimeout = 60

      read if parsenow
    end

    # Read the configuration file.
    def read
      return unless FileTest.exists?(@file)

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
          f.each { |line|
            case line
            when /^\s*#/ # skip comments
              count += 1
              next
            when /^\s*$/  # skip blank lines
              count += 1
              next
            when /^(?:(\[[\w.]+\])|(path)\s+((?:~\s+)?[^ ]+))\s*$/ # "namespace" or "namespace.method" or "path /path" or "path ~ regex"
              name = $1
              name = $3 if $2 == "path"
              name.chomp!
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
        #raise Puppet::Error, "Cannot read #{@config}"
      rescue Errno::ENOENT => detail
        Puppet.err "Configuration error: '#{@file}' does not exit; cannot serve"
        #raise Puppet::Error, "#{@config} does not exit"
      #rescue FileServerError => detail
      #    Puppet.err "FileServer error: #{detail}"
      end

      # Verify each of the rights are valid.
      # We let the check raise an error, so that it can raise an error
      # pointing to the specific problem.
      newrights.each { |name, right|
        right.valid?
      }
      @rights = newrights
    end

    def parse_right_directive(right, var, value, count)
      value.strip!
      case var
      when "allow"
        modify_right(right, :allow, value, "allowing %s access", count)
      when "deny"
        modify_right(right, :deny, value, "denying %s access", count)
      when "method"
        unless right.acl_type == :regex
          raise ConfigurationError, "'method' directive not allowed in namespace ACL at line #{count} of #{@config}"
        end
        modify_right(right, :restrict_method, value, "allowing 'method' %s", count)
      when "environment"
        unless right.acl_type == :regex
          raise ConfigurationError, "'environment' directive not allowed in namespace ACL at line #{count} of #{@config}"
        end
        modify_right(right, :restrict_environment, value, "adding environment %s", count)
      when /auth(?:enticated)?/
        unless right.acl_type == :regex
          raise ConfigurationError, "'authenticated' directive not allowed in namespace ACL at line #{count} of #{@config}"
        end
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

