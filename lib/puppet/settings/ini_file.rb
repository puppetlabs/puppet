# @api private
class Puppet::Settings::IniFile
  DEFAULT_SECTION_NAME = "main"

  def self.update(config_fh, &block)
    config = parse(config_fh)
    manipulator = Manipulator.new(config)
    yield manipulator
    config.write(config_fh)
  end

  def self.parse(config_fh)
    lines = [DefaultSection.new]
    config_fh.each_line do |line|
      case line
      when /^(\s*)\[(\w+)\](\s*)$/
        lines << SectionLine.new(lines[-1], $1, $2, $3)
      when /^(\s*)(\w+)(\s*=\s*)(.*?)(\s*)$/
        lines << SettingLine.new(lines[-1], $1, $2, $3, $4, $5)
      else
        lines << Line.new(lines[-1], line)
      end
    end

    new(lines)
  end

  def initialize(lines = [])
    @lines = lines
  end

  def add_section(name)
    @lines << SectionLine.new(@lines[-1], "", name, "")
  end

  def add_setting(name, value)
    @lines << SettingLine.new(@lines[-1], "", name, "=", value, "")
  end

  def each(&block)
    @lines.each(&block)
  end

  def sections
    sections = @lines.select { |line| line.is_a?(SectionLine) }
  end

  def setting(section, name)
    lines_in(section).find do |line|
      line.is_a?(SettingLine) && line.name == name
    end
  end

  def lines_in(section)
    section_lines = []
    current_section = DEFAULT_SECTION_NAME
    @lines.each do |line|
      if line.is_a?(SectionLine)
        current_section = line.name
      elsif current_section == section
        section_lines << line
      end
    end

    section_lines
  end

  def write(fh)
    fh.truncate(0)
    fh.rewind
    @lines.each do |line|
      line.write(fh)
    end
    fh.flush
  end

  class Manipulator
    def initialize(config)
      @config = config
    end

    def set(section, name, value)
      setting = @config.setting(section, name)
      if setting
        setting.value = value
      else
        @config.add_section(section)
        @config.add_setting(name, value)
      end
    end
  end

  module LineNumber
    def line_number
      line = 0
      previous_line = previous
      while previous_line
        line += 1
        previous_line = previous_line.previous
      end
      line
    end
  end

  Line = Struct.new(:previous, :text) do
    include LineNumber

    def write(fh)
      fh.puts(text)
    end
  end

  SettingLine = Struct.new(:previous, :prefix, :name, :infix, :value, :suffix) do
    include LineNumber

    def write(fh)
      fh.write(prefix)
      fh.write(name)
      fh.write(infix)
      fh.write(value)
      fh.puts(suffix)
    end
  end

  SectionLine = Struct.new(:previous, :prefix, :name, :suffix) do
    include LineNumber

    def write(fh)
      fh.write(prefix)
      fh.write("[")
      fh.write(name)
      fh.write("]")
      fh.puts(suffix)
    end
  end

  class DefaultSection < SectionLine
    def initialize
      super(nil, "", DEFAULT_SECTION_NAME, "")
    end

    def write(fh)
    end
  end
end
