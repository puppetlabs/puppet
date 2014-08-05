require 'puppet/file_system/file19'

class Puppet::FileSystem::File2 < Puppet::FileSystem::File19
  def compare_stream(path, stream)
    open(path, 0, 'rb') do |a|
      # use FileUtils 1.9 implementation because of problems with encodings
      bsize = FileUtils.send :fu_stream_blksize, a, stream
      sa = sb = nil
      while sa == sb
        sa = a.read(bsize)
        sb = stream.read(bsize)
        unless sa and sb
          if sa.nil? and sb.nil?
            return true
          end
        end
      end
      false
    end
  end
end
