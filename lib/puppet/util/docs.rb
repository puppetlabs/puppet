# Some simple methods for helping manage automatic documentation generation.
module Puppet::Util::Docs
  # Specify the actual doc string.
  def desc(str)
    @doc = str
  end

  # Add a new autodoc block.  We have to define these as class methods,
  # rather than just sticking them in a hash, because otherwise they're
  # too difficult to do inheritance with.
  def dochook(name, &block)
    method = "dochook_#{name}"

    meta_def method, &block
  end

  attr_writer :doc

  # Generate the full doc string.
  def doc
    extra = methods.find_all { |m| m.to_s =~ /^dochook_.+/ }.sort.collect { |m|
      self.send(m)
    }.delete_if {|r| r.nil? }.collect {|r| "* #{r}"}.join("\n")

    if @doc
      scrub(@doc) + (extra.empty? ? '' : "\n\n#{extra}")
    else
      extra
    end
  end

  # Build a table
  def doctable(headers, data)
    str = "\n\n"

    lengths = []
    # Figure out the longest field for all columns
    data.each do |name, values|
      [name, values].flatten.each_with_index do |value, i|
        lengths[i] ||= 0
        lengths[i] = value.to_s.length if value.to_s.length > lengths[i]
      end
    end

    # The headers could also be longest
    headers.each_with_index do |value, i|
      lengths[i] = value.to_s.length if value.to_s.length > lengths[i]
    end

    # Add the header names
    str += headers.zip(lengths).collect { |value, num| pad(value, num) }.join(" | ") + " |" + "\n"

    # And the header row
    str += lengths.collect { |num| "-" * num }.join(" | ") + " |" + "\n"

    # Now each data row
    data.sort { |a, b| a[0].to_s <=> b[0].to_s }.each do |name, rows|
      str += [name, rows].flatten.zip(lengths).collect do |value, length|
        pad(value, length)
      end.join(" | ") + " |" + "\n"
    end

    str + "\n"
  end

  # There is nothing that would ever set this. It gets read in reference/type.rb, but will never have any value but nil.
  attr_reader :nodoc
  def nodoc?
    nodoc
  end

  # Pad a field with spaces
  def pad(value, length)
    value.to_s + (" " * (length - value.to_s.length))
  end

  HEADER_LEVELS = [nil, "#", "##", "###", "####", "#####"]

  def markdown_header(name, level)
    "#{HEADER_LEVELS[level]} #{name}\n\n"
  end

  def markdown_definitionlist(term, definition)
    lines = scrub(definition).split("\n")
    str = "#{term}\n: #{lines.shift}\n"
    lines.each do |line|
      str << "  " if line =~ /\S/
      str << "#{line}\n"
    end
    str << "\n"
  end

  # Strip indentation and trailing whitespace from embedded doc fragments.
  #
  # Multi-line doc fragments are sometimes indented in order to preserve the
  # formatting of the code they're embedded in. Since indents are syntactic
  # elements in Markdown, we need to make sure we remove any indent that was
  # added solely to preserve surrounding code formatting, but LEAVE any indent
  # that delineates a Markdown element (code blocks, multi-line bulleted list
  # items). We can do this by removing the *least common indent* from each line.
  #
  # Least common indent is defined as follows:
  #
  # * Find the smallest amount of leading space on any line...
  # * ...excluding the first line (which may have zero indent without affecting
  #   the common indent)...
  # * ...and excluding lines that consist solely of whitespace.
  # * The least common indent may be a zero-length string, if the fragment is
  #   not indented to match code.
  # * If there are hard tabs for some dumb reason, we assume they're at least
  #   consistent within this doc fragment.
  #
  # See tests in spec/unit/util/docs_spec.rb for examples.
  def scrub(text)
    # One-liners are easy! (One-liners may be buffered with extra newlines.)
    return text.strip if text.strip !~ /\n/
    excluding_first_line = text.partition("\n").last
    indent = excluding_first_line.scan(/^[ \t]*(?=\S)/).min || '' # prevent nil
    # Clean hanging indent, if any
    if indent.length > 0
      text = text.gsub(/^#{indent}/, '')
    end
    # Clean trailing space
    text.lines.map{|line|line.rstrip}.join("\n").rstrip
  end

  module_function :scrub
end
