require 'tempfile'

class Puppet::FileSystem::Tempfile

  # Variation of Tempfile.open which ensures that the tempfile is closed and
  # unlinked before returning
  #
  # @param identifier [String] additional part of generated pathname
  # @yieldparam file [File] the temporary file object
  # @return result of the passed block
  # @api private
  def self.open(identifier)
    file = ::Tempfile.new(identifier)

    yield file

  ensure
    file.close!
  end
end
