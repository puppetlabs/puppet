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
      case line.chomp
      when /^(\s*)\[([[:word:]]+)\](\s*)$/
        config.append(SectionLine.new($1, $2, $3))
      when /^(\s*)([[:word:]]+)(\s*=\s*)(.*?)(\s*)$/
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

  def delete(section, name)
    delete_offset = @lines.index(setting(section, name))
    next_offset = delete_offset + 1
    if next_offset < @lines.length
      @lines[next_offset].previous = @lines[delete_offset].previous
    end
    @lines.delete_at(delete_offset)
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

  def settings_exist_in_default_section?
    lines_in(DEFAULT_SECTION_NAME).any? { |line| line.is_a?(SettingLine) }
  end

  def section_exists_with_default_section_name?
    section_lines.any? do |section|
      !section.is_a?(DefaultSection) && section.name == DEFAULT_SECTION_NAME
    end
  end

  def set_default_section_write_sectionline(value)
    if index = @lines.find_index { |line| line.is_a?(DefaultSection) }
      @lines[index].write_sectionline = true
    end
  end

  def write(fh)
    # If no real section line for the default section exists, configure the
    # DefaultSection object to write its section line. (DefaultSection objects
    # don't write the section line unless explicitly configured to do so)
    if settings_exist_in_default_section? && !section_exists_with_default_section_name?
      set_default_section_write_sectionline(true)
    end

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

    def delete(section_name, name)
      setting = @config.setting(section_name, name)
      if setting
        @config.delete(section_name, name)
        setting.to_s.chomp
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

    def to_s
      text
    end

    def write(fh)
      fh.puts(to_s)
    end
  end

  SettingLine = Struct.new(:prefix, :name, :infix, :value, :suffix) do
    include LineNumber

    def to_s
      "#{prefix}#{name}#{infix}#{value}#{suffix}"
    end

    def write(fh)
      fh.puts(to_s)
    end

    def ==(other)
      super(other) && self.line_number == other.line_number
    end
  end

  SectionLine = Struct.new(:prefix, :name, :suffix) do
    include LineNumber

    def to_s
      "#{prefix}[#{name}]#{suffix}"
    end

    def write(fh)
      fh.puts(to_s)
    end
  end

  class DefaultSection < SectionLine
    attr_accessor :write_sectionline

    def initialize
      @write_sectionline = false
      super("", DEFAULT_SECTION_NAME, "")
    end

    def write(fh)
      if @write_sectionline
        super(fh)
      end
    end
  end
end
