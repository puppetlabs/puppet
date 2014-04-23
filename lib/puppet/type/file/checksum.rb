require 'puppet/util/checksums'

# Specify which checksum algorithm to use when checksumming
# files.
Puppet::Type.type(:file).newparam(:checksum) do
  include Puppet::Util::Checksums

  desc "The checksum type to use when determining whether to replace a file's contents.

    The default checksum type is md5."

  newvalues "md5", "md5lite", "sha256", "sha256lite", "mtime", "ctime", "none"

  defaultto do
    Puppet[:digest_algorithm].to_sym
  end

  def sum(content)
    type = digest_algorithm()
    "{#{type}}" + send(type, content)
  end

  def sum_file(path)
    type = digest_algorithm()
    method = type.to_s + "_file"
    "{#{type}}" + send(method, path).to_s
  end

  def sum_stream(&block)
    type = digest_algorithm()
    method = type.to_s + "_stream"
    checksum = send(method, &block)
    "{#{type}}#{checksum}"
  end

  private

  # Return the appropriate digest algorithm with fallbacks in case puppet defaults have not
  # been initialized.
  def digest_algorithm
    value || Puppet[:digest_algorithm].to_sym
  end
end
