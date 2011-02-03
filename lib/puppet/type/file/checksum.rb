require 'puppet/util/checksums'

# Specify which checksum algorithm to use when checksumming
# files.
Puppet::Type.type(:file).newparam(:checksum) do
  include Puppet::Util::Checksums

  desc "The checksum type to use when checksumming a file.

    The default checksum parameter, if checksums are enabled, is md5."

  newvalues "md5", "md5lite", "mtime", "ctime", "none"

  defaultto :md5

  def sum(content)
    type = value || :md5 # because this might be called before defaults are set
    "{#{type}}" + send(type, content)
  end

  def sum_file(path)
    type = value || :md5 # because this might be called before defaults are set
    method = type.to_s + "_file"
    "{#{type}}" + send(method, path).to_s
  end

  def sum_stream(&block)
    type = value || :md5 # same comment as above
    method = type.to_s + "_stream"
    checksum = send(method, &block)
    "{#{type}}#{checksum}"
  end
end
