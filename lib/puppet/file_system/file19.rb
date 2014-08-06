class Puppet::FileSystem::File19 < Puppet::FileSystem::FileImpl
  def binread(path)
    path.binread
  end

  # Provide an encoding agnostic version of compare_stream
  #
  # The FileUtils implementation in Ruby 2.0+ was modified in a manner where
  # it cannot properly compare File and StringIO instances. To sidestep that
  # issue this method reimplements the faster 2.0 version that will correctly
  # compare binary File and StringIO streams.
  def compare_stream(path, stream)
    open(path, 0, 'rb') do |this|
      bsize = FileUtils.send(:fu_stream_blksize, this, stream)
      sa = "".force_encoding('ASCII-8BIT')
      sb = "".force_encoding('ASCII-8BIT')
      begin
        this.read(bsize, sa)
        stream.read(bsize, sb)
        return true if sa.empty? && sb.empty?
      end while sa == sb
      false
    end
  end
end
