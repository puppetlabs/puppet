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

    # Does the file exist?  Puppet master does not require it, but
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
      #XXX So if you delete the file, that change is not picked up?
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

