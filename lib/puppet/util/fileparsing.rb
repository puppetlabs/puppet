# A mini-language for parsing files.  This is only used file the ParsedFile
# provider, but it makes more sense to split it out so it's easy to maintain
# in one place.
#
# You can use this module to create simple parser/generator classes.  For instance,
# the following parser should go most of the way to parsing /etc/passwd:
#
#   class Parser
#       include Puppet::Util::FileParsing
#       record_line :user, :fields => %w{name password uid gid gecos home shell},
#           :separator => ":"
#   end
#
# You would use it like this:
#
#   parser = Parser.new
#   lines = parser.parse(File.read("/etc/passwd"))
#
#   lines.each do |type, hash| # type will always be :user, since we only have one
#       p hash
#   end
#
# Each line in this case would be a hash, with each field set appropriately.
# You could then call 'parser.to_line(hash)' on any of those hashes to generate
# the text line again.

require 'puppet/util/methodhelper'

module Puppet::Util::FileParsing
  include Puppet::Util
  attr_writer :line_separator, :trailing_separator

  class FileRecord
    include Puppet::Util
    include Puppet::Util::MethodHelper
    attr_accessor :absent, :joiner, :rts, :separator, :rollup, :name, :match, :block_eval

    attr_reader :fields, :optional, :type

    INVALID_FIELDS = [:record_type, :target, :on_disk]

    # Customize this so we can do a bit of validation.
    def fields=(fields)
      @fields = fields.collect do |field|
        r = field.intern
        raise ArgumentError.new(_("Cannot have fields named %{name}") % { name: r }) if INVALID_FIELDS.include?(r)
        r
      end
    end

    def initialize(type, options = {}, &block)
      @type = type.intern
      raise ArgumentError, _("Invalid record type %{record_type}") % { record_type: @type } unless [:record, :text].include?(@type)

      set_options(options)

      if self.type == :record
        # Now set defaults.
        self.absent ||= ""
        self.separator ||= /\s+/
        self.joiner ||= " "
        self.optional ||= []
        @rollup = true unless defined?(@rollup)
      end

      if block_given?
        @block_eval ||= :process

        # Allow the developer to specify that a block should be instance-eval'ed.
        if @block_eval == :instance
          instance_eval(&block)
        else
          meta_def(@block_eval, &block)
        end
      end
    end

    # Convert a record into a line by joining the fields together appropriately.
    # This is pulled into a separate method so it can be called by the hooks.
    def join(details)
      joinchar = self.joiner

      fields.collect { |field|
        # If the field is marked absent, use the appropriate replacement
        if details[field] == :absent or details[field] == [:absent] or details[field].nil?
          if self.optional.include?(field)
            self.absent
          else
            raise ArgumentError, _("Field '%{field}' is required") % { field: field }
          end
        else
          details[field].to_s
        end
      }.reject { |c| c.nil?}.join(joinchar)
    end

    # Customize this so we can do a bit of validation.
    def optional=(optional)
      @optional = optional.collect do |field|
        field.intern
      end
    end

    # Create a hook that modifies the hash resulting from parsing.
    def post_parse=(block)
      meta_def(:post_parse, &block)
    end

    # Create a hook that modifies the hash just prior to generation.
    def pre_gen=(block)
      meta_def(:pre_gen, &block)
    end

    # Are we a text type?
    def text?
      type == :text
    end

    def to_line=(block)
      meta_def(:to_line, &block)
    end
  end

  # Clear all existing record definitions.  Only used for testing.
  def clear_records
    @record_types.clear
    @record_order.clear
  end

  def fields(type)
    if record = record_type(type)
      record.fields.dup
    else
      nil
    end
  end

  # Try to match a specific text line.
  def handle_text_line(line, record)
    line =~ record.match ? {:record_type => record.name, :line => line} : nil
  end

  # Try to match a record.
  #
  # @param [String] line The line to be parsed
  # @param [Puppet::Util::FileType] record The filetype to use for parsing
  #
  # @return [Hash<Symbol, Object>] The parsed elements of the line
  def handle_record_line(line, record)
    ret = nil
    if record.respond_to?(:process)
      if ret = record.send(:process, line.dup)
        unless ret.is_a?(Hash)
          raise Puppet::DevError, _("Process record type %{record_name} returned non-hash") % { record_name: record.name }
        end
      else
        return nil
      end
    elsif regex = record.match
      # In this case, we try to match the whole line and then use the
      # match captures to get our fields.
      if match = regex.match(line)
        ret = {}
        record.fields.zip(match.captures).each do |field, value|
          if value == record.absent
            ret[field] = :absent
          else
            ret[field] = value
          end
        end
      else
        nil
      end
    else
      ret = {}
      sep = record.separator

      # String "helpfully" replaces ' ' with /\s+/ in splitting, so we
      # have to work around it.
      if sep == " "
        sep = / /
      end
      line_fields = line.split(sep)
      record.fields.each do |param|
        value = line_fields.shift
        if value and value != record.absent
          ret[param] = value
        else
          ret[param] = :absent
        end
      end

      if record.rollup and ! line_fields.empty?
        last_field = record.fields[-1]
        val = ([ret[last_field]] + line_fields).join(record.joiner)
        ret[last_field] = val
      end
    end

    if ret
      ret[:record_type] = record.name
      return ret
    else
      return nil
    end
  end

  def line_separator
    @line_separator ||= "\n"

    @line_separator
  end

  # Split text into separate lines using the record separator.
  def lines(text)
    # NOTE: We do not have to remove trailing separators because split will ignore
    # them by default (unless you pass -1 as a second parameter)
    text.split(self.line_separator)
  end

  # Split a bunch of text into lines and then parse them individually.
  def parse(text)
    count = 1
    lines(text).collect do |line|
      count += 1
      if val = parse_line(line)
        val
      else
        error = Puppet::ResourceError.new(_("Could not parse line %{line}") % { line: line.inspect })
        error.line = count
        raise error
      end
    end
  end

  # Handle parsing a single line.
  def parse_line(line)
    raise Puppet::DevError, _("No record types defined; cannot parse lines") unless records?

    @record_order.each do |record|
      # These are basically either text or record lines.
      method = "handle_#{record.type}_line"
      if respond_to?(method)
        if result = send(method, line, record)
          record.send(:post_parse, result) if record.respond_to?(:post_parse)
          return result
        end
      else
        raise Puppet::DevError, _("Somehow got invalid line type %{record_type}") % { record_type: record.type }
      end
    end

    nil
  end

  # Define a new type of record.  These lines get split into hashes.  Valid
  # options are:
  # * <tt>:absent</tt>: What to use as value within a line, when a field is
  #   absent.  Note that in the record object, the literal :absent symbol is
  #   used, and not this value.  Defaults to "".
  # * <tt>:fields</tt>: The list of fields, as an array.  By default, all
  #   fields are considered required.
  # * <tt>:joiner</tt>: How to join fields together.  Defaults to '\t'.
  # * <tt>:optional</tt>: Which fields are optional.  If these are missing,
  #   you'll just get the 'absent' value instead of an ArgumentError.
  # * <tt>:rts</tt>: Whether to remove trailing whitespace.  Defaults to false.
  #   If true, whitespace will be removed; if a regex, then whatever matches
  #   the regex will be removed.
  # * <tt>:separator</tt>: The record separator.  Defaults to /\s+/.
  def record_line(name, options, &block)
    raise ArgumentError, _("Must include a list of fields") unless options.include?(:fields)

    record = FileRecord.new(:record, options, &block)
    record.name = name.intern

    new_line_type(record)
  end

  # Are there any record types defined?
  def records?
    defined?(@record_types) and ! @record_types.empty?
  end

  # Define a new type of text record.
  def text_line(name, options, &block)
    raise ArgumentError, _("You must provide a :match regex for text lines") unless options.include?(:match)

    record = FileRecord.new(:text, options, &block)
    record.name = name.intern

    new_line_type(record)
  end

  # Generate a file from a bunch of hash records.
  def to_file(records)
    text = records.collect { |record| to_line(record) }.join(line_separator)

    text += line_separator if trailing_separator

    text
  end

  # Convert our parsed record into a text record.
  def to_line(details)
    unless record = record_type(details[:record_type])
      raise ArgumentError, _("Invalid record type %{record_type}") % { record_type: details[:record_type].inspect }
    end

    if record.respond_to?(:pre_gen)
      details = details.dup
      record.send(:pre_gen, details)
    end

    case record.type
    when :text; return details[:line]
    else
      return record.to_line(details) if record.respond_to?(:to_line)

      line = record.join(details)

      if regex = record.rts
        # If they say true, then use whitespace; else, use their regex.
        if regex == true
          regex = /\s+$/
        end
        return line.sub(regex,'')
      else
        return line
      end
    end
  end

  # Whether to add a trailing separator to the file.  Defaults to true
  def trailing_separator
    if defined?(@trailing_separator)
      return @trailing_separator
    else
      return true
    end
  end

  def valid_attr?(type, attr)
    type = type.intern
    if record = record_type(type) and record.fields.include?(attr.intern)
      return true
    else
      if attr.intern == :ensure
        return true
      else
        false
      end
    end
  end

  private

  # Define a new type of record.
  def new_line_type(record)
    @record_types ||= {}
    @record_order ||= []

    raise ArgumentError, _("Line type %{name} is already defined") % { name: record.name } if @record_types.include?(record.name)

    @record_types[record.name] = record
    @record_order << record

    record
  end

  # Retrieve the record object.
  def record_type(type)
    @record_types[type.intern]
  end
end

