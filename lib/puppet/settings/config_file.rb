require 'puppet/settings/ini_file'

##
# @api private
#
# Parses puppet configuration files
#
class Puppet::Settings::ConfigFile

  ALLOWED_SECTION_NAMES = ['main', 'master', 'agent', 'user'].freeze

  ##
  # @param value_converter [Proc] a function that will convert strings into ruby types
  #
  def initialize(value_converter)
    @value_converter = value_converter
  end

  def parse_file(file, text)
    result = Conf.new

    ini = Puppet::Settings::IniFile.parse(StringIO.new(text))
    unique_sections_in(ini, file).each do |section_name|
      section = Section.new(section_name.to_sym)
      result.with_section(section)

      ini.lines_in(section_name).each do |line|
        if line.is_a?(Puppet::Settings::IniFile::SettingLine)
          parse_setting(line, section)
        elsif line.text !~ /^\s*#|^\s*$/
          raise Puppet::Settings::ParseError.new("Could not match line #{line.text}", file, line.line_number)
        end
      end
    end

    result
  end

  Conf = Struct.new(:sections) do
    def initialize
      super({})
    end

    def with_section(section)
      sections[section.name] = section
      self
    end
  end

  Section = Struct.new(:name, :settings) do
    def initialize(name)
      super(name, [])
    end

    def with_setting(name, value, meta)
      settings << Setting.new(name, value, meta)
      self
    end

    def setting(name)
      settings.find { |setting| setting.name == name }
    end
  end

  Setting = Struct.new(:name, :value, :meta) do
    def has_metadata?
      meta != NO_META
    end
  end

  Meta = Struct.new(:owner, :group, :mode)
  NO_META = Meta.new(nil, nil, nil)

private

  def unique_sections_in(ini, file)
    ini.section_lines.collect do |section|
      if section.name == "application_defaults" || section.name == "global_defaults"
        raise Puppet::Error, "Illegal section '#{section.name}' in config file #{file} at line #{section.line_number}"
      end
      if !ALLOWED_SECTION_NAMES.include?(section.name)
        Puppet.deprecation_warning("Sections other than #{ALLOWED_SECTION_NAMES.join(', ')} are deprecated in puppet.conf. Please use the directory environments feature to specify environments. (See http://docs.puppetlabs.com/puppet/latest/reference/environments.html)")
      end
      section.name
    end.uniq
  end

  def parse_setting(setting, section)
    var = setting.name.intern

    # We don't want to munge modes, because they're specified in octal, so we'll
    # just leave them as a String, since Puppet handles that case correctly.
    if var == :mode
      value = setting.value
    else
      value = @value_converter[setting.value]
    end

    # Check to see if this is a file argument and it has extra options
    begin
      if value.is_a?(String) and options = extract_fileinfo(value)
        section.with_setting(var, options[:value], Meta.new(options[:owner],
                                                            options[:group],
                                                            options[:mode]))
      else
        section.with_setting(var, value, NO_META)
      end
    rescue Puppet::Error => detail
      raise Puppet::Settings::ParseError.new(detail.message, file, setting.line_number, detail)
    end
  end

  def empty_section
    { :_meta => {} }
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
