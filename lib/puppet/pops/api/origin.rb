require 'uri'

module Puppet; module Pops; module API
  
  # Origin describes a position in some file. If an instance is created without
  # arguments, it will bind to the position in code where Origin.new is called (i.e.
  # the __FILE__ and __LINE__ where the call takes place).
  # 
  # More detailed information may be passed by specifying an offset (0 based) starting from
  # the beginning of the file, and where length specifies the number of characters from
  # this position.
  # 
  # Unspecified line, offset and length
  # values can be stated as -1 (this is also the default if nothing is stated).
  #
  # The individual fields can be obtained via #file, #line, #offset and #length, or as a
  # combined URI, with the path and URI query parameters line, offset and length.
  # Parameters offset and length are only included if they are not -1.
  # Scheme is typically nil for file: URIs, but may state file: if this was used when creating
  # the Origin instance.
  #
  class Origin
    attr_reader :file, :line, :offset, :length
    def initialize file = nil, line = nil, offset = -1, length = -1
      unless file
        caller[0] =~ /(.*):([0-9]*):.*/
        file = $1
        line = $2 unless line
      end
      
      @file = file
      @line = line ? line.to_i : -1
      @offset = offset.to_i
      @length = length.to_i
    end
    
    def uri
      uriargs = [file]
      uriargs << "?line=#{line}"
      uriargs << "&offset=#{offset}" if offset >= 0
      uriargs << "&length=#{length}" if offset >= 0 && length >= 0 
      URI(uriargs.join(''))
    end
    
  end
end; end; end