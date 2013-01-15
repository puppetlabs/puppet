#!/usr/bin/env ruby
# embed the code in puppet under the Puppet::Util namesapce
module Puppet
module Util

#--
# Archive::Tar::Minitar 0.5.2
#   Copyright 2004 Mauricio Julio Ferna'ndez Pradier and Austin Ziegler
#
# This program is based on and incorporates parts of RPA::Package from
# rpa-base (lib/rpa/package.rb and lib/rpa/util.rb) by Mauricio and has been
# adapted to be more generic by Austin.
#
# It is licensed under the GNU General Public Licence or Ruby's licence.
#
# $Id$
#++

module Archive; end
module Archive::Tar; end

  # = Archive::Tar::PosixHeader
  # Implements the POSIX tar header as a Ruby class. The structure of
  # the POSIX tar header is:
  #
  #   struct tarfile_entry_posix
  #   {                      //                               pack/unpack
  #      char name[100];     // ASCII (+ Z unless filled)     a100/Z100
  #      char mode[8];       // 0 padded, octal, null         a8  /A8
  #      char uid[8];        // ditto                         a8  /A8
  #      char gid[8];        // ditto                         a8  /A8
  #      char size[12];      // 0 padded, octal, null         a12 /A12
  #      char mtime[12];     // 0 padded, octal, null         a12 /A12
  #      char checksum[8];   // 0 padded, octal, null, space  a8  /A8
  #      char typeflag[1];   // see below                     a   /a
  #      char linkname[100]; // ASCII + (Z unless filled)     a100/Z100
  #      char magic[6];      // "ustar\0"                     a6  /A6
  #      char version[2];    // "00"                          a2  /A2
  #      char uname[32];     // ASCIIZ                        a32 /Z32
  #      char gname[32];     // ASCIIZ                        a32 /Z32
  #      char devmajor[8];   // 0 padded, octal, null         a8  /A8
  #      char devminor[8];   // 0 padded, octal, null         a8  /A8
  #      char prefix[155];   // ASCII (+ Z unless filled)     a155/Z155
  #   };
  #
  # The +typeflag+ may be one of the following known values:
  #
  # <tt>"0"</tt>::  Regular file. NULL should be treated as a synonym, for
  #                 compatibility purposes.
  # <tt>"1"</tt>::  Hard link.
  # <tt>"2"</tt>::  Symbolic link.
  # <tt>"3"</tt>::  Character device node.
  # <tt>"4"</tt>::  Block device node.
  # <tt>"5"</tt>::  Directory.
  # <tt>"6"</tt>::  FIFO node.
  # <tt>"7"</tt>::  Reserved.
  #
  # POSIX indicates that "A POSIX-compliant implementation must treat any
  # unrecognized typeflag value as a regular file."
class Archive::Tar::PosixHeader
  FIELDS = %w(name mode uid gid size mtime checksum typeflag linkname) +
           %w(magic version uname gname devmajor devminor prefix)

  FIELDS.each { |field| attr_reader field.intern }

  HEADER_PACK_FORMAT    = "a100a8a8a8a12a12a7aaa100a6a2a32a32a8a8a155"
  HEADER_UNPACK_FORMAT  = "Z100A8A8A8A12A12A8aZ100A6A2Z32Z32A8A8Z155"

    # Creates a new PosixHeader from a data stream.
  def self.new_from_stream(stream, long_name = nil)
    data = stream.read(512)
    fields    = data.unpack(HEADER_UNPACK_FORMAT)
    name      = fields.shift
    mode      = fields.shift.oct
    uid       = fields.shift.oct
    gid       = fields.shift.oct
    size      = fields.shift.oct
    mtime     = fields.shift.oct
    checksum  = fields.shift.oct
    typeflag  = fields.shift
    linkname  = fields.shift
    magic     = fields.shift
    version   = fields.shift.oct
    uname     = fields.shift
    gname     = fields.shift
    devmajor  = fields.shift.oct
    devminor  = fields.shift.oct
    prefix    = fields.shift

    empty = (data == "\0" * 512)

    if typeflag == 'L' && name == '././@LongLink'
	    long_name = stream.read(512).rstrip
    	return new_from_stream(stream, long_name)
    end

    new(:name => long_name || name,
	:mode => mode, :uid => uid, :gid => gid,
        :size => size, :mtime => mtime, :checksum => checksum,
        :typeflag => typeflag, :magic => magic, :version => version,
        :uname => uname, :gname => gname, :devmajor => devmajor,
        :devminor => devminor, :prefix => prefix, :empty => empty)
  end

    # Creates a new PosixHeader. A PosixHeader cannot be created unless the
    # #name, #size, #prefix, and #mode are provided.
  def initialize(vals)
    unless vals[:name] && vals[:size] && vals[:prefix] && vals[:mode]
      raise ArgumentError
    end

    vals[:mtime]    ||= 0
    vals[:checksum] ||= ""
    vals[:typeflag] ||= "0"
    vals[:magic]    ||= "ustar"
    vals[:version]  ||= "00"

    FIELDS.each do |field|
      instance_variable_set("@#{field}", vals[field.intern])
    end
    @empty = vals[:empty]
  end

  def empty?
    @empty
  end

  def to_s
    update_checksum
    header(@checksum)
  end

    # Update the checksum field.
  def update_checksum
    hh = header(" " * 8)
    @checksum = oct(calculate_checksum(hh), 6)
  end

  private
  def oct(num, len)
    if num.nil?
      "\0" * (len + 1)
    else
      "%0#{len}o" % num
    end
  end

  def calculate_checksum(hdr)
    hdr.unpack("C*").inject { |aa, bb| aa + bb }
  end

  def header(chksum)
    arr = [name, oct(mode, 7), oct(uid, 7), oct(gid, 7), oct(size, 11),
    oct(mtime, 11), chksum, " ", typeflag, linkname, magic, version,
    uname, gname, oct(devmajor, 7), oct(devminor, 7), prefix]
    str = arr.pack(HEADER_PACK_FORMAT)
    str + "\0" * ((512 - str.size) % 512)
  end
end

require 'fileutils'
require 'find'

  # = Archive::Tar::Minitar 0.5.2
  # Archive::Tar::Minitar is a pure-Ruby library and command-line
  # utility that provides the ability to deal with POSIX tar(1) archive
  # files. The implementation is based heavily on Mauricio Ferna'ndez's
  # implementation in rpa-base, but has been reorganised to promote
  # reuse in other projects.
  #
  # This tar class performs a subset of all tar (POSIX tape archive)
  # operations. We can only deal with typeflags 0, 1, 2, and 5 (see
  # Archive::Tar::PosixHeader). All other typeflags will be treated as
  # normal files.
  #
  # NOTE::: support for typeflags 1 and 2 is not yet implemented in this
  #         version.
  #
  # This release is version 0.5.2. The library can only handle files and
  # directories at this point. A future version will be expanded to
  # handle symbolic links and hard links in a portable manner. The
  # command line utility, minitar, can only create archives, extract
  # from archives, and list archive contents.
  #
  # == Synopsis
  # Using this library is easy. The simplest case is:
  #
  #   require 'zlib'
  #   require 'archive/tar/minitar'
  #   include Archive::Tar
  #
  #     # Packs everything that matches Find.find('tests')
  #   File.open('test.tar', 'wb') { |tar| Minitar.pack('tests', tar) }
  #     # Unpacks 'test.tar' to 'x', creating 'x' if necessary.
  #   Minitar.unpack('test.tar', 'x')
  #
  # A gzipped tar can be written with:
  #
  #   tgz = Zlib::GzipWriter.new(File.open('test.tgz', 'wb'))
  #     # Warning: tgz will be closed!
  #   Minitar.pack('tests', tgz)
  #
  #   tgz = Zlib::GzipReader.new(File.open('test.tgz', 'rb'))
  #     # Warning: tgz will be closed!
  #   Minitar.unpack(tgz, 'x')
  #
  # As the case above shows, one need not write to a file. However, it
  # will sometimes require that one dive a little deeper into the API,
  # as in the case of StringIO objects. Note that I'm not providing a
  # block with Minitar::Output, as Minitar::Output#close automatically
  # closes both the Output object and the wrapped data stream object.
  #
  #   begin
  #     sgz = Zlib::GzipWriter.new(StringIO.new(""))
  #     tar = Output.new(sgz)
  #     Find.find('tests') do |entry|
  #       Minitar.pack_file(entry, tar)
  #     end
  #   ensure
  #       # Closes both tar and sgz.
  #     tar.close
  #   end
  #
  # == Copyright
  # Copyright 2004 Mauricio Julio Ferna'ndez Pradier and Austin Ziegler
  #
  # This program is based on and incorporates parts of RPA::Package from
  # rpa-base (lib/rpa/package.rb and lib/rpa/util.rb) by Mauricio and
  # has been adapted to be more generic by Austin.
  #
  # 'minitar' contains an adaptation of Ruby/ProgressBar by Satoru
  # Takabayashi <satoru@namazu.org>, copyright 2001 - 2004.
  #
  # This program is free software. It may be redistributed and/or
  # modified under the terms of the GPL version 2 (or later) or Ruby's
  # licence.
module Archive::Tar::Minitar
  VERSION = "0.5.4"

    # The exception raised when a wrapped data stream class is expected to
    # respond to #rewind or #pos but does not.
  class NonSeekableStream < StandardError; end
    # The exception raised when a block is required for proper operation of
    # the method.
  class BlockRequired < ArgumentError; end
    # The exception raised when operations are performed on a stream that has
    # previously been closed.
  class ClosedStream < StandardError; end
    # The exception raised when a filename exceeds 256 bytes in length,
    # the maximum supported by the standard Tar format.
  class FileNameTooLong < StandardError; end
    # The exception raised when a data stream ends before the amount of data
    # expected in the archive's PosixHeader.
  class UnexpectedEOF < StandardError; end

    # The class that writes a tar format archive to a data stream.
  class Writer
      # A stream wrapper that can only be written to. Any attempt to read
      # from this restricted stream will result in a NameError being thrown.
    class RestrictedStream
      def initialize(anIO)
        @io = anIO
      end

      def write(data)
        @io.write(data)
      end
    end

      # A RestrictedStream that also has a size limit.
    class BoundedStream < Archive::Tar::Minitar::Writer::RestrictedStream
        # The exception raised when the user attempts to write more data to
        # a BoundedStream than has been allocated.
      class FileOverflow < RuntimeError; end

        # The maximum number of bytes that may be written to this data
        # stream.
      attr_reader :limit
        # The current total number of bytes written to this data stream.
      attr_reader :written

      def initialize(io, limit)
        @io       = io
        @limit    = limit
        @written  = 0
      end

      def write(data)
        raise FileOverflow if (data.size + @written) > @limit
        @io.write(data)
        @written += data.size
        data.size
      end
    end

      # With no associated block, +Writer::open+ is a synonym for
      # +Writer::new+. If the optional code block is given, it will be
      # passed the new _writer_ as an argument and the Writer object will
      # automatically be closed when the block terminates. In this instance,
      # +Writer::open+ returns the value of the block.
    def self.open(anIO)
      writer = Writer.new(anIO)

      return writer unless block_given?

      begin
        res = yield writer
      ensure
        writer.close
      end

      res
    end

      # Creates and returns a new Writer object.
    def initialize(anIO)
      @io     = anIO
      @closed = false
    end

      # Adds a file to the archive as +name+. +opts+ must contain the
      # following values:
      #
      # <tt>:mode</tt>::  The Unix file permissions mode value.
      # <tt>:size</tt>::  The size, in bytes.
      #
      # +opts+ may contain the following values:
      #
      # <tt>:uid</tt>:    The Unix file owner user ID number.
      # <tt>:gid</tt>:    The Unix file owner group ID number.
      # <tt>:mtime</tt>:: The *integer* modification time value.
      #
      # It will not be possible to add more than <tt>opts[:size]</tt> bytes
      # to the file.
    def add_file_simple(name, opts = {}) # :yields BoundedStream:
      raise Archive::Tar::Minitar::BlockRequired unless block_given?
      raise Archive::Tar::ClosedStream if @closed

      name, prefix = split_name(name)

      header = { :name => name, :mode => opts[:mode], :mtime => opts[:mtime],
        :uname => opts[:uname], :gname => opts[:gname],
        :size => opts[:size], :gid => opts[:gid], :uid => opts[:uid],
        :prefix => prefix }
      header = Archive::Tar::PosixHeader.new(header).to_s 
      @io.write(header)

      os = BoundedStream.new(@io, opts[:size])
      yield os
        # FIXME: what if an exception is raised in the block?

      min_padding = opts[:size] - os.written
      @io.write("\0" * min_padding)
      remainder = (512 - (opts[:size] % 512)) % 512
      @io.write("\0" * remainder)
    end

      # Adds a file to the archive as +name+. +opts+ must contain the
      # following value:
      #
      # <tt>:mode</tt>::  The Unix file permissions mode value.
      #
      # +opts+ may contain the following values:
      #
      # <tt>:uid</tt>:    The Unix file owner user ID number.
      # <tt>:gid</tt>:    The Unix file owner group ID number.
      # <tt>:mtime</tt>:: The *integer* modification time value.
      #
      # The file's size will be determined from the amount of data written
      # to the stream.
      #
      # For #add_file to be used, the Archive::Tar::Minitar::Writer must be
      # wrapping a stream object that is seekable (e.g., it responds to
      # #pos=). Otherwise, #add_file_simple must be used.
      #
      # +opts+ may be modified during the writing to the stream.
    def add_file(name, opts = {}) # :yields RestrictedStream, +opts+:
      raise Archive::Tar::Minitar::BlockRequired unless block_given?
      raise Archive::Tar::Minitar::ClosedStream if @closed
      raise Archive::Tar::Minitar::NonSeekableStream unless @io.respond_to?(:pos=)

      name, prefix = split_name(name)
      init_pos = @io.pos
      @io.write("\0" * 512) # placeholder for the header

      yield RestrictedStream.new(@io), opts
        # FIXME: what if an exception is raised in the block?

      size      = @io.pos - (init_pos + 512)
      remainder = (512 - (size % 512)) % 512
      @io.write("\0" * remainder)

      final_pos = @io.pos
      @io.pos   = init_pos

      header = { :name => name, :mode => opts[:mode], :mtime => opts[:mtime],
                 :uname => opts[:uname], :gname => opts[:gname],
                 :size => size, :gid => opts[:gid], :uid => opts[:uid],
                 :prefix => prefix }
      header = Archive::Tar::PosixHeader.new(header).to_s
      @io.write(header)
      @io.pos = final_pos
    end

      # Add a symlink to the tar.
    def add_symlink(name, target, opts = {})
      raise ClosedStream if @closed
      name, prefix = split_name(name)
      header = { :name => name, :mode => opts[:mode] || 0777,
                 :uname => opts[:uname], :gname => opts[:gname],
                 :typeflag => "2", :size => 0,
                 :prefix => prefix, :linkname => target }
      header = Archive::Tar::PosixHeader.new(header).to_s
      @io.write(header)
      nil
    end

      # Creates a directory in the tar.
    def mkdir(name, opts = {})
      raise ClosedStream if @closed
      name, prefix = split_name(name)
      header = { :name => name, :mode => opts[:mode], :typeflag => "5",
                 :uname => opts[:uname], :gname => opts[:gname],
                 :size => 0, :gid => opts[:gid], :uid => opts[:uid],
                 :mtime => opts[:mtime], :prefix => prefix }
      header = Archive::Tar::PosixHeader.new(header).to_s
      @io.write(header)
      nil
    end

      # Passes the #flush method to the wrapped stream, used for buffered
      # streams.
    def flush
      raise ClosedStream if @closed
      @io.flush if @io.respond_to?(:flush)
    end

      # Closes the Writer.
    def close
      return if @closed
      @io.write("\0" * 1024)
      @closed = true
    end

    private
    def split_name(name)
      raise FileNameTooLong if name.size > 256
      if name.size <= 100
        prefix = ""
      else
        parts = name.split(/\//)
        newname = parts.pop

        nxt = ""

        loop do
          nxt = parts.pop
          break if newname.size + 1 + nxt.size > 100
          newname = "#{nxt}/#{newname}"
        end

        prefix = (parts + [nxt]).join("/")

        name = newname

        raise FileNameTooLong if name.size > 100 || prefix.size > 155
      end
      return name, prefix
    end
  end

    # The class that reads a tar format archive from a data stream. The data
    # stream may be sequential or random access, but certain features only work
    # with random access data streams.
  class Reader
      # This marks the EntryStream closed for reading without closing the
      # actual data stream.
    module InvalidEntryStream
      def read(len = nil); raise ClosedStream; end
      def getc; raise ClosedStream;  end
      def rewind; raise ClosedStream;  end
    end
      
      # EntryStreams are pseudo-streams on top of the main data stream.
    class EntryStream
      Archive::Tar::PosixHeader::FIELDS.each do |field|
        attr_reader field.intern
      end

      def initialize(header, anIO)
        @io       = anIO
        @name     = header.name
        @mode     = header.mode
        @uid      = header.uid
        @gid      = header.gid
        @size     = header.size
        @mtime    = header.mtime
        @checksum = header.checksum
        @typeflag = header.typeflag
        @linkname = header.linkname
        @magic    = header.magic
        @version  = header.version
        @uname    = header.uname
        @gname    = header.gname
        @devmajor = header.devmajor
        @devminor = header.devminor
        @prefix   = header.prefix
        @read     = 0
        @orig_pos = @io.pos
      end

        # Reads +len+ bytes (or all remaining data) from the entry. Returns
        # +nil+ if there is no more data to read.
      def read(len = nil)
        return nil if @read >= @size
        len ||= @size - @read
        max_read = [len, @size - @read].min
        ret = @io.read(max_read)
        @read += ret.size
        ret
      end

        # Reads one byte from the entry. Returns +nil+ if there is no more data
        # to read.
      def getc
        return nil if @read >= @size
        ret = @io.getc
        @read += 1 if ret
        ret
      end

        # Returns +true+ if the entry represents a directory.
      def directory?
        @typeflag == "5"
      end
      alias_method :directory, :directory?

        # Returns +true+ if the entry represents a symbolic link.
      def symlink?
        @typeflag == "2"
      end
      alias_method :symlink, :symlink?

        # Returns +true+ if the entry represents a plain file.
      def file?
        @typeflag == "0" or @typeflag == "\0"
      end
      alias_method :file, :file?

        # Returns +true+ if the current read pointer is at the end of the
        # EntryStream data.
      def eof?
        @read >= @size
      end

        # Returns the current read pointer in the EntryStream.
      def pos
        @read
      end

        # Sets the current read pointer to the beginning of the EntryStream.
      def rewind
        raise NonSeekableStream unless @io.respond_to?(:pos=)
        @io.pos = @orig_pos
        @read = 0
      end

      def bytes_read
        @read
      end

        # Returns the full and proper name of the entry.
      def full_name
        if @prefix != ""
          File.join(@prefix, @name)
        else
          @name
        end
      end

        # Closes the entry.
      def close
        invalidate
      end

      private
      def invalidate
        extend InvalidEntryStream
      end
    end

      # With no associated block, +Reader::open+ is a synonym for
      # +Reader::new+. If the optional code block is given, it will be passed
      # the new _writer_ as an argument and the Reader object will
      # automatically be closed when the block terminates. In this instance,
      # +Reader::open+ returns the value of the block.
    def self.open(anIO)
      reader = Reader.new(anIO)

      return reader unless block_given?

      begin
        res = yield reader
      ensure
        reader.close
      end
      
      res
    end

      # Creates and returns a new Reader object.
    def initialize(anIO)
      @io     = anIO
      @init_pos = anIO.pos
    end

      # Iterates through each entry in the data stream.
    def each(&block)
      each_entry(&block)
    end

      # Resets the read pointer to the beginning of data stream. Do not call
      # this during a #each or #each_entry iteration. This only works with
      # random access data streams that respond to #rewind and #pos.
    def rewind
      if @init_pos == 0
        raise NonSeekableStream unless @io.respond_to?(:rewind)
        @io.rewind
      else
        raise NonSeekableStream unless @io.respond_to?(:pos=)
        @io.pos = @init_pos
      end
    end

      # Iterates through each entry in the data stream.
    def each_entry
      loop do
        return if @io.eof?

        header = Archive::Tar::PosixHeader.new_from_stream(@io)
        return if header.empty?

        entry = EntryStream.new(header, @io)
        size  = entry.size

        yield entry

        skip = (512 - (size % 512)) % 512

        if @io.respond_to?(:seek)
            # avoid reading...
          @io.seek(size - entry.bytes_read, IO::SEEK_CUR)
        else
          pending = size - entry.bytes_read
          while pending > 0
            bread = @io.read([pending, 4096].min).size
            raise UnexpectedEOF if @io.eof?
            pending -= bread
          end
        end
        @io.read(skip) # discard trailing zeros
          # make sure nobody can use #read, #getc or #rewind anymore
        entry.close
      end
    end

    def close
    end
  end

    # Wraps a Archive::Tar::Minitar::Reader with convenience methods and
    # wrapped stream management; Input only works with random access data
    # streams. See Input::new for details.
  class Input
    include Enumerable

      # With no associated block, +Input::open+ is a synonym for
      # +Input::new+. If the optional code block is given, it will be passed
      # the new _writer_ as an argument and the Input object will
      # automatically be closed when the block terminates. In this instance,
      # +Input::open+ returns the value of the block.
    def self.open(input)
      stream = Input.new(input)
      return stream unless block_given?

      begin
        res = yield stream
      ensure
        stream.close
      end

      res
    end

      # Creates a new Input object. If +input+ is a stream object that responds
      # to #read), then it will simply be wrapped. Otherwise, one will be
      # created and opened using Kernel#open. When Input#close is called, the
      # stream object wrapped will be closed.
    def initialize(input)
      if input.respond_to?(:read)
        @io = input
      else
        @io = open(input, "rb")
      end
      @tarreader = Archive::Tar::Minitar::Reader.new(@io)
    end

      # Iterates through each entry and rewinds to the beginning of the stream
      # when finished.
    def each(&block)
      @tarreader.each { |entry| yield entry }
    ensure
      @tarreader.rewind
    end

      # Extracts the current +entry+ to +destdir+. If a block is provided, it
      # yields an +action+ Symbol, the full name of the file being extracted
      # (+name+), and a Hash of statistical information (+stats+).
      #
      # The +action+ will be one of:
      # <tt>:dir</tt>::           The +entry+ is a directory.
      # <tt>:file_start</tt>::    The +entry+ is a file; the extract of the
      #                           file is just beginning.
      # <tt>:file_progress</tt>:: Yielded every 4096 bytes during the extract
      #                           of the +entry+.
      # <tt>:file_done</tt>::     Yielded when the +entry+ is completed.
      #
      # The +stats+ hash contains the following keys:
      # <tt>:current</tt>:: The current total number of bytes read in the
      #                     +entry+.
      # <tt>:currinc</tt>:: The current number of bytes read in this read
      #                     cycle.
      # <tt>:entry</tt>::   The entry being extracted; this is a
      #                     Reader::EntryStream, with all methods thereof.
    def extract_entry(destdir, entry) # :yields action, name, stats:
      stats = {
        :current  => 0,
        :currinc  => 0,
        :entry    => entry
      }

      if entry.directory?
        dest = File.join(destdir, entry.full_name)

        yield :dir, entry.full_name, stats if block_given?

        if Archive::Tar::Minitar.dir?(dest)
          begin
            FileUtils.chmod(entry.mode, dest)
          rescue Exception
            nil
          end
        else
          FileUtils.mkdir_p(dest, :mode => entry.mode)
          FileUtils.chmod(entry.mode, dest)
        end

        fsync_dir(dest)
        fsync_dir(File.join(dest, ".."))
        return
      else # it's a file
        destdir = File.join(destdir, File.dirname(entry.full_name))
        FileUtils.mkdir_p(destdir, :mode => 0755)

        destfile = File.join(destdir, File.basename(entry.full_name))
        FileUtils.chmod(0600, destfile) rescue nil  # Errno::ENOENT

        yield :file_start, entry.full_name, stats if block_given?

        File.open(destfile, "wb", entry.mode) do |os|
          loop do
            data = entry.read(4096)
            break unless data

            stats[:currinc] = os.write(data)
            stats[:current] += stats[:currinc]

            yield :file_progress, entry.full_name, stats if block_given?
          end
          os.fsync
        end

        FileUtils.chmod(entry.mode, destfile)
        fsync_dir(File.dirname(destfile))
        fsync_dir(File.join(File.dirname(destfile), ".."))

        yield :file_done, entry.full_name, stats if block_given?
      end
    end

      # Returns the Reader object for direct access.
    def tar
      @tarreader
    end

      # Closes the Reader object and the wrapped data stream.
    def close
      @io.close
      @tarreader.close
    end

  private
    def fsync_dir(dirname)
        # make sure this hits the disc
      dir = open(dirname, 'rb')
      dir.fsync
    rescue # ignore IOError if it's an unpatched (old) Ruby
      nil
    ensure
      dir.close if dir rescue nil
    end
  end

    # Wraps a Archive::Tar::Minitar::Writer with convenience methods and
    # wrapped stream management; Output only works with random access data
    # streams. See Output::new for details.
  class Output
      # With no associated block, +Output::open+ is a synonym for
      # +Output::new+. If the optional code block is given, it will be passed
      # the new _writer_ as an argument and the Output object will
      # automatically be closed when the block terminates. In this instance,
      # +Output::open+ returns the value of the block.
    def self.open(output)
      stream = Output.new(output)
      return stream unless block_given?

      begin
        res = yield stream
      ensure
        stream.close
      end

      res
    end

      # Creates a new Output object. If +output+ is a stream object that
      # responds to #read), then it will simply be wrapped. Otherwise, one will
      # be created and opened using Kernel#open. When Output#close is called,
      # the stream object wrapped will be closed.
    def initialize(output)
      if output.respond_to?(:write)
        @io = output
      else
        @io = ::File.open(output, "wb")
      end
      @tarwriter = Archive::Tar::Minitar::Writer.new(@io)
    end

      # Returns the Writer object for direct access.
    def tar
      @tarwriter
    end

      # Closes the Writer object and the wrapped data stream.
    def close
      @tarwriter.close
      @io.close
    end
  end

  class << self
      # Tests if +path+ refers to a directory. Fixes an apparently
      # corrupted <tt>stat()</tt> call on Windows.
    def dir?(path)
      File.directory?((path[-1] == ?/) ? path : "#{path}/")
    end

      # A convenience method for wrapping Archive::Tar::Minitar::Input.open
      # (mode +r+) and Archive::Tar::Minitar::Output.open (mode +w+). No other
      # modes are currently supported.
    def open(dest, mode = "r", &block)
      case mode
      when "r"
        Input.open(dest, &block)
      when "w"
        Output.open(dest, &block)
      else
        raise "Unknown open mode for Archive::Tar::Minitar.open."
      end
    end

      # A convenience method to packs the file provided. +entry+ may either be
      # a filename (in which case various values for the file (see below) will
      # be obtained from <tt>File#stat(entry)</tt> or a Hash with the fields:
      #
      # <tt>:name</tt>::  The filename to be packed into the tarchive.
      #                   *REQUIRED*.
      # <tt>:mode</tt>::  The mode to be applied.
      # <tt>:uid</tt>::   The user owner of the file. (Ignored on Windows.)
      # <tt>:gid</tt>::   The group owner of the file. (Ignored on Windows.)
      # <tt>:mtime</tt>:: The modification Time of the file.
      #
      # During packing, if a block is provided, #pack_file yields an +action+
      # Symol, the full name of the file being packed, and a Hash of
      # statistical information, just as with
      # Archive::Tar::Minitar::Input#extract_entry.
      #
      # The +action+ will be one of:
      # <tt>:dir</tt>::           The +entry+ is a directory.
      # <tt>:file_start</tt>::    The +entry+ is a file; the extract of the
      #                           file is just beginning.
      # <tt>:file_progress</tt>:: Yielded every 4096 bytes during the extract
      #                           of the +entry+.
      # <tt>:file_done</tt>::     Yielded when the +entry+ is completed.
      #
      # The +stats+ hash contains the following keys:
      # <tt>:current</tt>:: The current total number of bytes read in the
      #                     +entry+.
      # <tt>:currinc</tt>:: The current number of bytes read in this read
      #                     cycle.
      # <tt>:name</tt>::    The filename to be packed into the tarchive.
      #                     *REQUIRED*.
      # <tt>:mode</tt>::    The mode to be applied.
      # <tt>:uid</tt>::     The user owner of the file. (+nil+ on Windows.)
      # <tt>:gid</tt>::     The group owner of the file. (+nil+ on Windows.)
      # <tt>:mtime</tt>::   The modification Time of the file.
    def pack_file(entry, outputter) #:yields action, name, stats:
      outputter = outputter.tar if outputter.kind_of?(Archive::Tar::Minitar::Output)

      stats = {}

      if entry.kind_of?(Hash)
        name = entry[:name]

        entry.each { |kk, vv| stats[kk] = vv unless vv.nil? }
      else
        name = entry
      end
      
      name = name.sub(%r{\./}, '')
      stat = File.stat(name)
      stats[:mode]   ||= stat.mode
      stats[:mtime]  ||= stat.mtime
      stats[:size]   = stat.size

      if RUBY_PLATFORM =~ /win32/
        stats[:uid]  = nil
        stats[:gid]  = nil
      else
        stats[:uid]  ||= stat.uid
        stats[:gid]  ||= stat.gid
      end

      case
      when File.file?(name)
        outputter.add_file_simple(name, stats) do |os|
          stats[:current] = 0
          yield :file_start, name, stats if block_given?
          File.open(name, "rb") do |ff|
            until ff.eof?
              stats[:currinc] = os.write(ff.read(4096))
              stats[:current] += stats[:currinc]
              yield :file_progress, name, stats if block_given?
            end
          end
          yield :file_done, name, stats if block_given?
        end
      when dir?(name)
        yield :dir, name, stats if block_given?
        outputter.mkdir(name, stats)
      else
        raise "Don't yet know how to pack this type of file."
      end
    end

      # A convenience method to pack files specified by +src+ into +dest+. If
      # +src+ is an Array, then each file detailed therein will be packed into
      # the resulting Archive::Tar::Minitar::Output stream; if +recurse_dirs+
      # is true, then directories will be recursed.
      #
      # If +src+ is an Array, it will be treated as the argument to Find.find;
      # all files matching will be packed.
    def pack(src, dest, recurse_dirs = true, &block)
      Output.open(dest) do |outp|
        if src.kind_of?(Array)
          src.each do |entry|
            pack_file(entry, outp, &block)
            if dir?(entry) and recurse_dirs
              Dir["#{entry}/**/**"].each do |ee|
                pack_file(ee, outp, &block)
              end
            end
          end
        else
          Find.find(src) do |entry|
            pack_file(entry, outp, &block)
          end
        end
      end
    end

      # A convenience method to unpack files from +src+ into the directory
      # specified by +dest+. Only those files named explicitly in +files+
      # will be extracted.
    def unpack(src, dest, files = [], &block)
      Input.open(src) do |inp|
        if File.exist?(dest) and (not dir?(dest))
          raise "Can't unpack to a non-directory."
        elsif not File.exist?(dest)
          FileUtils.mkdir_p(dest)
        end

        inp.each do |entry|
          if files.empty? or files.include?(entry.full_name)
            inp.extract_entry(dest, entry, &block)
          end
        end
      end
    end
  end
end

# end of embeding under the Puppet::Util namesapce
end
end
