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
          #TRANSLATORS "path" is a configuration file entry and should not be translated
          raise Puppet::ConfigurationError, _("Missing or invalid 'path' before right directive at %{error_location}") %
              { error_location: Puppet::Util::Errors.error_location(@file, count) }
        end
        parse_right_directive(right, $1, $2, count)
      else
        error_location_str = Puppet::Util::Errors.error_location(nil, count)
        raise Puppet::ConfigurationError, _("Invalid entry at %{error_location}: %{file_text}") %
            { error_location: error_location_str, file_text: line }
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
      modify_right(right, :allow, value, _("allowing %{value} access"), count)
    when "deny"
      modify_right(right, :deny, value, _("denying %{value} access"), count)
    when "allow_ip"
      modify_right(right, :allow_ip, value, _("allowing IP %{value} access"), count)
    when "deny_ip"
      modify_right(right, :deny_ip, value, _("denying IP %{value} access"), count)
    when "method"
      modify_right(right, :restrict_method, value, _("allowing 'method' %{value}"), count)
    when "environment"
      modify_right(right, :restrict_environment, value, _("adding environment %{value}"), count)
    when /auth(?:enticated)?/
      modify_right(right, :restrict_authenticated, value, _("adding authentication %{value}"), count)
    else
      error_location_str = Puppet::Util::Errors.error_location(nil, count)
      raise Puppet::ConfigurationError, _("Invalid argument '%{var}' at %{error_location}") %
          { var: var, error_location: error_location_str }
    end
  end

  def modify_right(right, method, value, msg, count)
    value.split(/\s*,\s*/).each do |val|
      begin
        val.strip!
        right.info msg % { value: val }
        right.send(method, val)
      rescue Puppet::AuthStoreError => detail
        error_location_str = Puppet::Util::Errors.error_location(@file, count)
        raise Puppet::ConfigurationError, "#{detail} #{error_location_str}", detail.backtrace
      end
    end
  end
end
end
