require 'puppet/network/rights'

module Puppet::Network
class AuthConfigParser

  def self.new_from_file(file)
    self.new(Puppet::FileSystem.read(file, :encoding => 'utf-8'))
  end

  def initialize(string)
    @string = string
  end

  def parse
    Puppet::Network::AuthConfig.new(parse_rights)
  end

  def parse_rights
    rights = Puppet::Network::Rights.new
    right = nil
    count = 1
    @string.each_line { |line|
      case line.chomp
      when /^\s*#/, /^\s*$/
        # skip comments and blank lines
      when /^path\s+((?:~\s+)?[^ ]+)\s*$/ # "path /path" or "path ~ regex"
        name = $1.chomp
        right = rights.newright(name, count, @file)
      when /^\s*(allow(?:_ip)?|deny(?:_ip)?|method|environment|auth(?:enticated)?)\s+(.+?)(\s*#.*)?$/
        if right.nil?
          raise Puppet::ConfigurationError, "Missing or invalid 'path' before right directive at line #{count} of #{@file}"
        end
        parse_right_directive(right, $1, $2, count)
      else
        raise Puppet::ConfigurationError, "Invalid line #{count}: #{line}"
      end
      count += 1
    }

    # Verify each of the rights are valid.
    # We let the check raise an error, so that it can raise an error
    # pointing to the specific problem.
    rights.each { |name, r|
      r.valid?
    }
    rights
  end

  def parse_right_directive(right, var, value, count)
    value.strip!
    case var
    when "allow"
      modify_right(right, :allow, value, "allowing %s access", count)
    when "deny"
      modify_right(right, :deny, value, "denying %s access", count)
    when "allow_ip"
      modify_right(right, :allow_ip, value, "allowing IP %s access", count)
    when "deny_ip"
      modify_right(right, :deny_ip, value, "denying IP %s access", count)
    when "method"
      modify_right(right, :restrict_method, value, "allowing 'method' %s", count)
    when "environment"
      modify_right(right, :restrict_environment, value, "adding environment %s", count)
    when /auth(?:enticated)?/
      modify_right(right, :restrict_authenticated, value, "adding authentication %s", count)
    else
      raise Puppet::ConfigurationError,
        "Invalid argument '#{var}' at line #{count}"
    end
  end

  def modify_right(right, method, value, msg, count)
    value.split(/\s*,\s*/).each do |val|
      begin
        val.strip!
        right.info msg % val
        right.send(method, val)
      rescue Puppet::AuthStoreError => detail
        raise Puppet::ConfigurationError, "#{detail} at line #{count} of #{@file}", detail.backtrace
      end
    end
  end
end
end
