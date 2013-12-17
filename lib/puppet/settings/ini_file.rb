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
    config = new([DefaultSection.new])
    config_fh.each_line do |line|
      case line
      when /^(\s*)\[(\w+)\](\s*)$/
        config.append(SectionLine.new($1, $2, $3))
      when /^(\s*)(\w+)(\s*=\s*)(.*?)(\s*)$/
        config.append(SettingLine.new($1, $2, $3, $4, $5))
      else
        config.append(Line.new(line))
      end
    end

    config
  end

  def initialize(lines = [])
    @lines = lines
  end

  def append(line)
    line.previous = @lines.last
    @lines << line
  end

  def insert_after(line, new_line)
    new_line.previous = line

    insertion_point = @lines.index(line)
    @lines.insert(insertion_point + 1, new_line)
    if @lines.length > insertion_point + 2
      @lines[insertion_point + 2].previous = new_line
    end
  end

  def section_lines
    @lines.select { |line| line.is_a?(SectionLine) }
  end

  def section_line(name)
    section_lines.find { |section| section.name == name }
  end

  def setting(section, name)
    settings_in(lines_in(section)).find do |line|
      line.name == name
    end
  end

  def lines_in(section_name)
    section_lines = []
    current_section_name = DEFAULT_SECTION_NAME
    @lines.each do |line|
      if line.is_a?(SectionLine)
        current_section_name = line.name
      elsif current_section_name == section_name
        section_lines << line
      end
    end

    section_lines
  end

  def settings_in(lines)
    lines.select { |line| line.is_a?(SettingLine) }
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
        add_setting(section, name, value)
      end
    end

    private

    def add_setting(section_name, name, value)
      section = @config.section_line(section_name)
      if section.nil?
        previous_line = SectionLine.new("", section_name, "")
        @config.append(previous_line)
      else
        previous_line = @config.settings_in(@config.lines_in(section_name)).last || section
      end

      @config.insert_after(previous_line, SettingLine.new("", name, " = ", value, ""))
    end
  end

  module LineNumber
    attr_accessor :previous

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

  Line = Struct.new(:text) do
    include LineNumber

    def write(fh)
      fh.puts(text)
    end
  end

  SettingLine = Struct.new(:prefix, :name, :infix, :value, :suffix) do
    include LineNumber

    def write(fh)
      fh.write(prefix)
      fh.write(name)
      fh.write(infix)
      fh.write(value)
      fh.puts(suffix)
    end
  end

  SectionLine = Struct.new(:prefix, :name, :suffix) do
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
      super("", DEFAULT_SECTION_NAME, "")
    end

    def write(fh)
    end
  end
end
