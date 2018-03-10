module Puppet::Pops
module PN
  KEY_PATTERN = /^[A-Za-z_-][0-9A-Za-z_-]*$/

  def pnError(message)
    raise ArgumentError, message
  end

  def as_call(name)
    Call.new(name, self)
  end

  def as_parameters
    [self]
  end

  def ==(o)
    eql?(o)
  end

  def to_s
    s = ''
    format(nil, s)
    s
  end

  def with_name(name)
    Entry.new(name, self)
  end

  def double_quote(str, bld)
    bld << '"'
    str.each_codepoint do |codepoint|
      case codepoint
      when 0x09
        bld << '\\t'
      when 0x0a
        bld << '\\n'
      when 0x0d
        bld << '\\r'
      when 0x22
        bld << '\\"'
      when 0x5c
        bld << '\\\\'
      else
        if codepoint < 0x20
          bld << sprintf('\\o%3.3o', codepoint)
        elsif codepoint <= 0x7f
          bld << codepoint
        else
          bld << [codepoint].pack('U')
        end
      end
    end
    bld << '"'
  end

  def format_elements(elements, indent, b)
    elements.each_with_index do |e, i|
      if indent
        b << "\n" << indent.current
      elsif i > 0
        b << ' '
      end
      e.format(indent, b)
    end
  end

  class Indent
    attr_reader :current
    def initialize(indent = '  ', current = '')
      @indent = indent
      @current = current
    end

    def increase
      Indent.new(@indent, @current + @indent)
    end
  end

  class Call
    include PN
    attr_reader :name, :elements

    def initialize(name, *elements)
      @name = name
      @elements = elements
    end

    def [](idx)
      @elements[idx]
    end

    def as_call(name)
      Call.new(name, *@elements)
    end

    def as_parameters
      List.new(@elements)
    end

    def eql?(o)
      o.is_a?(Call) && @name == o.name && @elements == o.elements
    end

    def format(indent, b)
      b << '(' << @name
      if @elements.size > 0
        b << ' ' unless indent
        format_elements(@elements, indent ? indent.increase : nil, b)
      end
      b << ')'
    end

    def to_data
      { '^' => [@name] + @elements.map { |e| e.to_data } }
    end
  end

  class Entry
    attr_reader :key, :value
    def initialize(key, value)
      @key = key
      @value = value
    end

    def eql?(o)
      o.is_a?(Entry) && @key == o.key && @value == o.value
    end

    alias == eql?
  end

  class List
    include PN
    attr_reader :elements

    def initialize(elements)
      @elements = elements
    end

    def [](idx)
      @elements[idx]
    end

    def as_call(name)
      Call.new(name, *@elements)
    end

    def as_parameters
      @elements
    end

    def eql?(o)
      o.is_a?(List) && @elements == o.elements
    end

    def format(indent, b)
      b << '['
      format_elements(@elements, indent ? indent.increase : nil, b) unless @elements.empty?
      b << ']'
    end

    def to_data
      @elements.map { |e| e.to_data }
    end
  end

  class Literal
    include PN
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def format(indent, b)
      if @value.nil?
        b << 'nil'
      elsif value.is_a?(String)
        double_quote(value, b)
      else
        b << value.to_s
      end
    end

    def eql?(o)
      o.is_a?(Literal) && @value == o.value
    end

    def to_data
      @value
    end
  end

  class Map
    include PN
    attr_reader :entries

    def initialize(entries)
      entries.each { |e| pnError("key #{e.key} does not conform to pattern /#{KEY_PATTERN.source}/)") unless e.key =~ KEY_PATTERN }
      @entries = entries
    end

    def eql?(o)
      o.is_a?(Map) && @entries == o.entries
    end

    def format(indent, b)
      local_indent = indent ? indent.increase : nil
      b << '{'
      @entries.each_with_index do |e,i|
        if indent
          b << "\n" << local_indent.current
        elsif i > 0
          b << ' '
        end
        b << ':' << e.key
        b << ' '
        e.value.format(local_indent, b)
      end
      b << '}'
    end

    def to_data
      r = []
      @entries.each { |e| r << e.key << e.value.to_data }
      { '#' => r }
    end
  end
end
end

require_relative 'model/pn_transformer'
require_relative 'parser/pn_parser'

