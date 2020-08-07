module Puppet::Util::Windows::String
  def wide_string(str)
    # if given a nil string, assume caller wants to pass a nil pointer to win32
    return nil if str.nil?

    str.encode('UTF-16LE')
  end
  module_function :wide_string

  # Read a wide character string up until the first double null, and delete
  # any remaining null characters.
  def wstrip(str)
    str.force_encoding('UTF-16LE').encode('UTF-8', invalid: :replace, undef: :replace).
      split("\x00")[0].encode(Encoding.default_external)
  end
  module_function :wstrip
end
