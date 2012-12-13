require 'puppet/settings/errors'

##
# @api private
#
# Parses puppet configuration files
#
class Puppet::Settings::ConfigFile

  ##
  # @param value_converter [Proc] a function that will convert strings into ruby types
  #
  def initialize(value_converter)
    @value_converter = value_converter
  end

  def parse_file(file, text)
    result = {}
    count = 0

    # Default to 'main' for the section.
    section_name = :main
    result[section_name] = empty_section
    text.split(/\n/).each do |line|
      count += 1
      case line
      when /^\s*\[(\w+)\]\s*$/
        section_name = $1.intern
        fail_when_illegal_section_name(section_name, file, line)
        if result[section_name].nil?
          result[section_name] = empty_section
        end
      when /^\s*#/; next # Skip comments
      when /^\s*$/; next # Skip blanks
      when /^\s*(\w+)\s*=\s*(.*?)\s*$/ # settings
        var = $1.intern

        # We don't want to munge modes, because they're specified in octal, so we'll
        # just leave them as a String, since Puppet handles that case correctly.
        if var == :mode
          value = $2
        else
          value = @value_converter[$2]
        end

        # Check to see if this is a file argument and it has extra options
        begin
          if value.is_a?(String) and options = extract_fileinfo(value)
            value = options[:value]
            options.delete(:value)
            result[section_name][:_meta][var] = options
          end
          result[section_name][var] = value
        rescue Puppet::Error => detail
          raise Puppet::Settings::ParseError.new(detail.message, file, line, detail)
        end
      else
        raise Puppet::Settings::ParseError.new("Could not match line #{line}", file, line)
      end
    end

    result
  end

private

  def empty_section
    { :_meta => {} }
  end

  def fail_when_illegal_section_name(section, file, line)
    if section == :application_defaults or section == :global_defaults
      raise Puppet::Error, "Illegal section '#{section}' in config file #{file} at line #{line}"
    end
  end

  def extract_fileinfo(string)
    result = {}
    value = string.sub(/\{\s*([^}]+)\s*\}/) do
      params = $1
      params.split(/\s*,\s*/).each do |str|
        if str =~ /^\s*(\w+)\s*=\s*([\w\d]+)\s*$/
          param, value = $1.intern, $2
          result[param] = value
          raise ArgumentError, "Invalid file option '#{param}'" unless [:owner, :mode, :group].include?(param)

          if param == :mode and value !~ /^\d+$/
            raise ArgumentError, "File modes must be numbers"
          end
        else
          raise ArgumentError, "Could not parse '#{string}'"
        end
      end
      ''
    end
    result[:value] = value.sub(/\s*$/, '')
    result
  end
end
