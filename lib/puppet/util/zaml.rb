# encoding: UTF-8
#
# The above encoding line is a magic comment to set the default source encoding
# of this file for the Ruby interpreter.  It must be on the first or second
# line of the file if an interpreter is in use.  In Ruby 1.9 and later, the
# source encoding determines the encoding of String and Regexp objects created
# from this source file.  This explicit encoding is important becuase otherwise
# Ruby will pick an encoding based on LANG or LC_CTYPE environment variables.
# These may be different from site to site so it's important for us to
# establish a consistent behavior.  For more information on M17n please see:
# http://links.puppetlabs.com/understanding_m17n

# ZAML -- A partial replacement for YAML, writen with speed and code clarity
#         in mind.  ZAML fixes one YAML bug (loading Exceptions) and provides
#         a replacement for YAML.dump unimaginatively called ZAML.dump,
#         which is faster on all known cases and an order of magnitude faster
#         with complex structures.
#
# http://github.com/hallettj/zaml
#
# ## License (from upstream)
#
# Copyright (c) 2008-2009 ZAML contributers
#
# This program is dual-licensed under the GNU General Public License
# version 3 or later and under the Apache License, version 2.0.
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version; or under the terms of the Apache License,
# Version 2.0.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License and the Apache License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
#
# You may obtain a copy of the Apache License at
# <https://www.apache.org/licenses/LICENSE-2.0.html>.

require 'yaml'

class ZAML
  VERSION = "0.1.3"
  #
  # Class Methods
  #
  def self.dump(stuff, where='')
    z = new
    stuff.to_zaml(z)
    where << z.to_s
  end

  #
  # Instance Methods
  #
  def initialize
    @result = []
    @indent = nil
    @structured_key_prefix = nil
    @previously_emitted_object = {}
    @next_free_label_number = 0
    emit('--- ')
  end

  def nested(tail='  ')
    old_indent = @indent
    @indent = "#{@indent || "\n"}#{tail}"
    yield
    @indent = old_indent
  end

  class Label
    #
    # YAML only wants objects in the datastream once; if the same object
    #    occurs more than once, we need to emit a label ("&idxxx") on the
    #    first occurrence and then emit a back reference (*idxxx") on any
    #    subsequent occurrence(s).
    #
    # To accomplish this we keeps a hash (by object id) of the labels of
    #    the things we serialize as we begin to serialize them.  The labels
    #    initially serialize as an empty string (since most objects are only
    #    going to be be encountered once), but can be changed to a valid
    #    (by assigning it a number) the first time it is subsequently used,
    #    if it ever is.  Note that we need to do the label setup BEFORE we
    #    start to serialize the object so that circular structures (in
    #    which we will encounter a reference to the object as we serialize
    #    it can be handled).
    #
    attr_accessor :this_label_number

    def initialize(obj,indent)
      @indent = indent
      @this_label_number = nil
      @obj = obj # prevent garbage collection so that object id isn't reused
    end

    def to_s
      @this_label_number ? ('&id%03d%s' % [@this_label_number, @indent]) : ''
    end

    def reference
      @reference         ||= '*id%03d' % @this_label_number
    end
  end

  def label_for(obj)
    @previously_emitted_object[obj.object_id]
  end

  def new_label_for(obj)
    label = Label.new(obj,(Hash === obj || Array === obj) ? "#{@indent || "\n"}  " : ' ')
    @previously_emitted_object[obj.object_id] = label
    label
  end

  def first_time_only(obj)
    if label = label_for(obj)
      label.this_label_number ||= (@next_free_label_number += 1)
      emit(label.reference)
    else
      with_structured_prefix(obj) do
        emit(new_label_for(obj))
        yield
      end
    end
  end

  def with_structured_prefix(obj)
    if @structured_key_prefix
      unless obj.is_a?(String) and obj !~ /\n/
        emit(@structured_key_prefix)
        @structured_key_prefix = nil
      end
    end
    yield
  end

  def emit(s)
    @result << s
    @recent_nl = false unless s.kind_of?(Label)
  end

  def nl(s = nil)
    emit(@indent || "\n") unless @recent_nl
    emit(s) if s
    @recent_nl = true
  end

  def to_s
    @result.join
  end

  def prefix_structured_keys(x)
    @structured_key_prefix = x
    yield
    nl unless @structured_key_prefix
    @structured_key_prefix = nil
  end
end

################################################################
#
#   Behavior for custom classes
#
################################################################

class Object
  # Users of this method need to do set math consistently with the
  # result. Since #instance_variables returns strings in 1.8 and symbols
  # on 1.9, standardize on symbols
  if RUBY_VERSION[0,3] == '1.8'
    def to_yaml_properties
      instance_variables.map(&:to_sym)
    end
  else
    def to_yaml_properties
      instance_variables
    end
  end

  def yaml_property_munge(x)
    x
  end

  def zamlized_class_name(root)
    cls = self.class
    "!ruby/#{root.name.downcase}#{cls == root ? '' : ":#{cls.respond_to?(:name) ? cls.name : cls}"}"
  end

  def to_zaml(z)
    z.first_time_only(self) {
      z.emit(zamlized_class_name(Object))
      z.nested {
        instance_variables = to_yaml_properties
        if instance_variables.empty?
          z.emit(" {}")
        else
          instance_variables.each { |v|
            z.nl
            v.to_s[1..-1].to_zaml(z)       # Remove leading '@'
            z.emit(': ')
            yaml_property_munge(instance_variable_get(v)).to_zaml(z)
          }
        end
      }
    }
  end
end

################################################################
#
#   Behavior for built-in classes
#
################################################################

class NilClass
  def to_zaml(z)
    z.emit('')        # NOTE: blank turns into nil in YAML.load
  end
end

class Symbol
  def to_zaml(z)
    z.emit("!ruby/sym ")
    to_s.to_zaml(z)
  end
end

class TrueClass
  def to_zaml(z)
    z.emit('true')
  end
end

class FalseClass
  def to_zaml(z)
    z.emit('false')
  end
end

class Numeric
  def to_zaml(z)
    z.emit(self)
  end
end

class Regexp
  def to_zaml(z)
    z.first_time_only(self) { z.emit("#{zamlized_class_name(Regexp)} #{inspect}") }
  end
end

class Exception
  def to_zaml(z)
    z.emit(zamlized_class_name(Exception))
    z.nested {
      z.nl("message: ")
      message.to_zaml(z)
    }
  end
  #
  # Monkey patch for buggy Exception restore in YAML
  #
  #     This makes it work for now but is not very future-proof; if things
  #     change we'll most likely want to remove this.  To mitigate the risks
  #     as much as possible, we test for the bug before appling the patch.
  #
  if respond_to? :yaml_new and yaml_new(self, :tag, "message" => "blurp").message != "blurp"
    def self.yaml_new( klass, tag, val )
      o = YAML.object_maker( klass, {} ).exception(val.delete( 'message'))
      val.each_pair do |k,v|
        o.instance_variable_set("@#{k}", v)
      end
      o
    end
  end
end

class String
  ZAML_ESCAPES = {
    "\a" => "\\a", "\e" => "\\e", "\f" => "\\f", "\n" => "\\n",
    "\r" => "\\r", "\t" => "\\t", "\v" => "\\v"
  }

  def to_zaml(z)
    z.with_structured_prefix(self) do
      case
      when self == ''
        z.emit('""')
      when self.to_ascii8bit !~ /\A(?: # ?: non-capturing group (grouping with no back references)
                 [\x09\x0A\x0D\x20-\x7E]            # ASCII
               | [\xC2-\xDF][\x80-\xBF]             # non-overlong 2-byte
               |  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
               | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
               |  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
               |  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
               | [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
               |  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
               )*\z/mnx
        # Emit the binary tag, then recurse. Ruby splits BASE64 output at the 60
        # character mark when packing strings, and we can wind up a multi-line
        # string here.  We could reimplement the multi-line string logic,
        # but why would we - this does just as well for producing solid output.
        z.emit("!binary ")
        [self].pack("m*").to_zaml(z)

      # Only legal UTF-8 characters can make it this far, so we are safe
      # against emitting something dubious. That means we don't need to mess
      # about, just emit them directly. --daniel 2012-07-14
      when ((self =~ /\A[a-zA-Z\/][-\[\]_\/.a-zA-Z0-9]*\z/) and
          (self !~ /^(?:true|false|yes|no|on|null|off)$/i))
        # simple string literal, safe to emit unquoted.
        z.emit(self)
      when (self =~ /\n/ and self !~ /\A\s/ and self !~ /\s\z/)
        # embedded newline, split line-wise in quoted string block form.
        if self[-1..-1] == "\n" then z.emit('|+') else z.emit('|-') end
        z.nested { split("\n",-1).each { |line| z.nl; z.emit(line) } }
      else
        # ...though we still have to escape unsafe characters.
        escaped = gsub(/[\\"\x00-\x1F]/) do |c|
          ZAML_ESCAPES[c] || "\\x#{c[0].ord.to_s(16)}"
        end
        z.emit("\"#{escaped}\"")
      end
    end
  end

  # Return a guranteed ASCII-8BIT encoding for Ruby 1.9 This is a helper
  # method for other methods that perform regular expressions against byte
  # sequences deliberately rather than dealing with characters.
  # The method may or may not return a new instance.
  if String.method_defined?(:encoding)
    ASCII_ENCODING = Encoding.find("ASCII-8BIT")
    def to_ascii8bit
      if self.encoding == ASCII_ENCODING
        self
      else
        self.dup.force_encoding(ASCII_ENCODING)
      end
    end
  else
    def to_ascii8bit
      self
    end
  end
end

class Hash
  def to_zaml(z)
    z.first_time_only(self) {
      z.nested {
        if empty?
          z.emit('{}')
        else
          each_pair { |k, v|
            z.nl
            z.prefix_structured_keys('? ') { k.to_zaml(z) }
            z.emit(': ')
            v.to_zaml(z)
          }
        end
      }
    }
  end
end

class Array
  def to_zaml(z)
    z.first_time_only(self) {
      z.nested {
        if empty?
          z.emit('[]')
        else
          each { |v| z.nl('- '); v.to_zaml(z) }
        end
      }
    }
  end
end

class Time
  def to_zaml(z)
    # 2008-12-06 10:06:51.373758 -07:00
    ms = ("%0.6f" % (usec * 1e-6))[2..-1]
    offset = "%+0.2i:%0.2i" % [utc_offset / 3600.0, (utc_offset / 60) % 60]
    z.emit(self.strftime("%Y-%m-%d %H:%M:%S.#{ms} #{offset}"))
  end
end

class Date
  def to_zaml(z)
    z.emit(strftime('%Y-%m-%d'))
  end
end

class Range
  def to_zaml(z)
    z.first_time_only(self) {
      z.emit(zamlized_class_name(Range))
      z.nested {
        z.nl
        z.emit('begin: ')
        z.emit(first)
        z.nl
        z.emit('end: ')
        z.emit(last)
        z.nl
        z.emit('excl: ')
        z.emit(exclude_end?)
      }
    }
  end
end
