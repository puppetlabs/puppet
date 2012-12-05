# -*- coding: utf-8 -*-
#
# CFTypes, e.g. CFString, CFInteger
# needed to create unambiguous plists
#
# Author::    Christian Kruse (mailto:cjk@wwwtech.de)
# Copyright:: Copyright (c) 2009
# License::   MIT License

require 'base64'

module Puppet::Vendor::CFPropertyList
  # This class defines the base class for all CFType classes
  #
  class CFType
    # value of the type
    attr_accessor :value

    def initialize(value=nil)
      @value = value
    end

    def to_xml(parser)
    end

    def to_binary(bplist) end
  end

  # This class holds string values, both, UTF-8 and UTF-16BE
  # It will convert the value to UTF-16BE if necessary (i.e. if non-ascii char contained)
  class CFString < CFType
    # convert to XML
    def to_xml(parser)
      n = parser.new_node('string')
      n = parser.append_node(n, parser.new_text(@value)) unless @value.nil?
      n
    end

    # convert to binary
    def to_binary(bplist)
      bplist.string_to_binary(@value);
    end
  end

  # This class holds integer/fixnum values
  class CFInteger < CFType
    # convert to XML
    def to_xml(parser)
      n = parser.new_node('integer')
      n = parser.append_node(n, parser.new_text(@value.to_s))
      n
    end

    # convert to binary
    def to_binary(bplist)
      bplist.num_to_binary(self)
    end
  end

  # This class holds float values
  class CFReal < CFType
    # convert to XML
    def to_xml(parser)
      n = parser.new_node('real')
      n = parser.append_node(n, parser.new_text(@value.to_s))
      n
    end

    # convert to binary
    def to_binary(bplist)
      bplist.num_to_binary(self)
    end
  end

  # This class holds Time values. While Apple uses seconds since 2001,
  # the rest of the world uses seconds since 1970. So if you access value
  # directly, you get the Time class. If you access via get_value you either
  # geht the timestamp or the Apple timestamp
  class CFDate < CFType
    TIMESTAMP_APPLE = 0
    TIMESTAMP_UNIX  = 1;
    DATE_DIFF_APPLE_UNIX = 978307200

    # create a XML date strimg from a time object
    def CFDate.date_string(val)
      # 2009-05-13T20:23:43Z
      val.getutc.strftime("%Y-%m-%dT%H:%M:%SZ")
    end

    # parse a XML date string
    def CFDate.parse_date(val)
      # 2009-05-13T20:23:43Z
      val =~ %r{^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$}
      year,month,day,hour,min,sec = $1, $2, $3, $4, $5, $6
      return Time.utc(year,month,day,hour,min,sec).getlocal
    end

    # set value to defined state
    def initialize(value = nil,format=CFDate::TIMESTAMP_UNIX)
      if(value.is_a?(Time) || value.nil?) then
        @value = value.nil? ? Time.now : value
      elsif value.instance_of? Date
        @value = Time.utc(value.year, value.month, value.day, 0, 0, 0)
      elsif value.instance_of? DateTime
        @value = value.to_time.utc
      else
        set_value(value,format)
      end
    end

    # set value with timestamp, either Apple or UNIX
    def set_value(value,format=CFDate::TIMESTAMP_UNIX)
      if(format == CFDate::TIMESTAMP_UNIX) then
        @value = Time.at(value)
      else
        @value = Time.at(value + CFDate::DATE_DIFF_APPLE_UNIX)
      end
    end

    # get timestamp, either UNIX or Apple timestamp
    def get_value(format=CFDate::TIMESTAMP_UNIX)
      if(format == CFDate::TIMESTAMP_UNIX) then
        @value.to_i
      else
        @value.to_f - CFDate::DATE_DIFF_APPLE_UNIX
      end
    end

    # convert to XML
    def to_xml(parser)
      n = parser.new_node('date')
      n = parser.append_node(n, parser.new_text(CFDate::date_string(@value)))
      n
    end

    # convert to binary
    def to_binary(bplist)
      bplist.date_to_binary(@value)
    end
  end

  # This class contains a boolean value
  class CFBoolean < CFType
    # convert to XML
    def to_xml(parser)
      parser.new_node(@value ? 'true' : 'false')
    end

    # convert to binary
    def to_binary(bplist)
      bplist.bool_to_binary(@value);
    end
  end

  # This class contains binary data values
  class CFData < CFType
    # Base64 encoded data
    DATA_BASE64 = 0
    # Raw data
    DATA_RAW = 1

    # set value to defined state, either base64 encoded or raw
    def initialize(value=nil,format=DATA_BASE64)
      if(format == DATA_RAW)
        @raw_value = value
        @raw_value.blob = true
      else
        @value = value
      end
    end

    # get base64 encoded value
    def encoded_value
      @value ||= "\n#{Base64.encode64(@raw_value).gsub("\n", '').scan(/.{1,76}/).join("\n")}\n"
    end

    # get base64 decoded value
    def decoded_value
      @raw_value ||= String.new(Base64.decode64(@value))
      @raw_value.blob = true
      @raw_value
    end

    # convert to XML
    def to_xml(parser)
      n = parser.new_node('data')
      n = parser.append_node(n, parser.new_text(encoded_value()))
      n
    end

    # convert to binary
    def to_binary(bplist)
      bplist.data_to_binary(decoded_value())
    end
  end

  # This class contains an array of values
  class CFArray < CFType
    # create a new array CFType
    def initialize(val=[])
      @value = val
    end

    # convert to XML
    def to_xml(parser)
      n = parser.new_node('array')
      @value.each do |v|
        n = parser.append_node(n, v.to_xml(parser))
      end
      n
    end

    # convert to binary
    def to_binary(bplist)
      bplist.array_to_binary(self)
    end
  end

  # this class contains a hash of values
  class CFDictionary < CFType
    # Create new CFDictonary type.
    def initialize(value={})
      @value = value
    end

    # convert to XML
    def to_xml(parser)
      n = parser.new_node('dict')
      @value.each_pair do |key, value|
        k = parser.append_node(parser.new_node('key'), parser.new_text(key.to_s))
        n = parser.append_node(n, k)
        n = parser.append_node(n, value.to_xml(parser))
      end
      n
    end

    # convert to binary
    def to_binary(bplist)
      bplist.dict_to_binary(self)
    end
  end
end

# eof
