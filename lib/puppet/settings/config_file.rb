require 'puppet/settings/ini_file'

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

    # Default to 'main' for the section.
    section_name = :main
    result[section_name] = empty_section
    Puppet::Settings::IniFile.parse(StringIO.new(text)).each do |line|
      case line
      when Puppet::Settings::IniFile::SectionLine
        section_name = line.name.intern
        fail_when_illegal_section_name(section_name, file, line.line)
        if result[section_name].nil?
          result[section_name] = empty_section
        end
      when Puppet::Settings::IniFile::SettingLine
        var = line.name.intern

        # We don't want to munge modes, because they're specified in octal, so we'll
        # just leave them as a String, since Puppet handles that case correctly.
        if var == :mode
          value = line.value
        else
          value = @value_converter[line.value]
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
        if line.text !~ /^\s*#|^\s*$/
          raise Puppet::Settings::ParseError.new("Could not match line #{line.text}", file, line.line)
        end
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
