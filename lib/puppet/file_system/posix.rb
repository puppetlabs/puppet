# frozen_string_literal: true

class Puppet::FileSystem::Posix < Puppet::FileSystem::FileImpl
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
    ::File.open(path, 'rb') do |this|
      bsize = stream_blksize(this, stream)
      sa = String.new.force_encoding('ASCII-8BIT')
      sb = String.new.force_encoding('ASCII-8BIT')
      loop do
        this.read(bsize, sa)
        stream.read(bsize, sb)
        return true if sa.empty? && sb.empty?
        break if sa != sb
      end
      false
    end
  end

  private

  def stream_blksize(*streams)
    streams.each do |s|
      next unless s.respond_to?(:stat)

      size = blksize(s.stat)
      return size if size
    end
    default_blksize()
  end

  def blksize(st)
    s = st.blksize
    return nil unless s
    return nil if s == 0

    s
  end

  def default_blksize
    1024
  end
end
