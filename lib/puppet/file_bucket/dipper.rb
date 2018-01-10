require 'pathname'
require 'puppet/file_bucket'
require 'puppet/file_bucket/file'
require 'puppet/indirector/request'
require 'puppet/util/diff'
require 'tempfile'

class Puppet::FileBucket::Dipper
  include Puppet::Util::Checksums
  # This is a transitional implementation that uses REST
  # to access remote filebucket files.

  attr_accessor :name

  # Creates a bucket client
  def initialize(hash = {})
    # Emulate the XMLRPC client
    server      = hash[:Server]
    port        = hash[:Port] || Puppet[:masterport]

    if hash.include?(:Path)
      @local_path = hash[:Path]
      @rest_path  = nil
    else
      @local_path = nil
      @rest_path = "filebucket://#{server}:#{port}/"
    end
    @checksum_type = Puppet[:digest_algorithm].to_sym
    @digest = method(@checksum_type)
  end

  def local?
    !! @local_path
  end

  # Backs up a file to the file bucket
  def backup(file)
    file_handle = Puppet::FileSystem.pathname(file)
    raise(ArgumentError, _("File %{file} does not exist") % { file: file }) unless Puppet::FileSystem.exist?(file_handle)
    begin
      file_bucket_file = Puppet::FileBucket::File.new(file_handle, :bucket_path => @local_path)
      files_original_path = absolutize_path(file)
      dest_path = "#{@rest_path}#{file_bucket_file.name}/#{files_original_path}"
      file_bucket_path = "#{@rest_path}#{file_bucket_file.checksum_type}/#{file_bucket_file.checksum_data}/#{files_original_path}"

      # Make a HEAD request for the file so that we don't waste time
      # uploading it if it already exists in the bucket.
      unless Puppet::FileBucket::File.indirection.head(file_bucket_path, :bucket_path => file_bucket_file.bucket_path)
        Puppet::FileBucket::File.indirection.save(file_bucket_file, dest_path)
      end

      return file_bucket_file.checksum_data
    rescue => detail
      message = _("Could not back up %{file}: %{detail}") % { file: file, detail: detail }
      Puppet.log_exception(detail, message)
      raise Puppet::Error, message, detail.backtrace
    end
  end

  # Diffs two filebucket files identified by their sums
  def diff(checksum_a, checksum_b, file_a, file_b)
    raise RuntimeError, _("Diff is not supported on this platform") if Puppet[:diff] == ""
    if checksum_a
      source_path = "#{@rest_path}#{@checksum_type}/#{checksum_a}"
      if checksum_b
        file_diff = Puppet::FileBucket::File.indirection.find(
          source_path,
          :bucket_path => @local_path,
          :diff_with => checksum_b)
      elsif file_b
        tmp_file = ::Tempfile.new('diff')
        begin
          restore(tmp_file.path, checksum_a)
          file_diff = Puppet::Util::Diff.diff(tmp_file.path, file_b)
        ensure
          tmp_file.close
          tmp_file.unlink
        end
      else
        raise Puppet::Error, _("Please provide a file or checksum do diff with")
      end
    elsif file_a
      if checksum_b
        tmp_file = ::Tempfile.new('diff')
        begin
          restore(tmp_file.path, checksum_b)
          file_diff = Puppet::Util::Diff.diff(file_a, tmp_file.path)
        ensure
          tmp_file.close
          tmp_file.unlink
        end
      elsif file_b
        file_diff = Puppet::Util::Diff.diff(file_a, file_b)
      end
    end
    raise Puppet::Error, _("Failed to diff files") unless file_diff
    file_diff.to_s
  end

  # Retrieves a file by sum.
  def getfile(sum)
    get_bucket_file(sum).to_s
  end

  # Retrieves a FileBucket::File by sum.
  def get_bucket_file(sum)
    source_path = "#{@rest_path}#{@checksum_type}/#{sum}"
    file_bucket_file = Puppet::FileBucket::File.indirection.find(source_path, :bucket_path => @local_path)

    raise Puppet::Error, _("File not found") unless file_bucket_file
    file_bucket_file
  end

  # Restores the file
  def restore(file, sum)
    restore = true
    file_handle = Puppet::FileSystem.pathname(file)
    if Puppet::FileSystem.exist?(file_handle)
      cursum = Puppet::FileBucket::File.new(file_handle).checksum_data()

      # if the checksum has changed...
      # this might be extra effort
      if cursum == sum
        restore = false
      end
    end

    if restore
      if newcontents = get_bucket_file(sum)
        newsum = newcontents.checksum_data
        changed = nil
        if Puppet::FileSystem.exist?(file_handle) and ! Puppet::FileSystem.writable?(file_handle)
          changed = Puppet::FileSystem.stat(file_handle).mode
          ::File.chmod(changed | 0200, file)
        end
        ::File.open(file, ::File::WRONLY|::File::TRUNC|::File::CREAT) { |of|
          of.binmode
          newcontents.stream do |source_stream|
            FileUtils.copy_stream(source_stream, of)
          end
        }
        ::File.chmod(changed, file) if changed
      else
        Puppet.err _("Could not find file with checksum %{sum}") % { sum: sum }
        return nil
      end
      return newsum
    else
      return nil
    end
  end

  # List Filebucket content.
  def list(fromdate, todate)
    raise Puppet::Error, _("Listing remote file buckets is not allowed") unless local?

    source_path = "#{@rest_path}#{@checksum_type}/"
    file_bucket_list = Puppet::FileBucket::File.indirection.find(
      source_path,
      :bucket_path => @local_path,
      :list_all => true,
      :fromdate => fromdate,
      :todate => todate)
    raise Puppet::Error, _("File not found") unless file_bucket_list
    file_bucket_list.to_s
  end

  private
  def absolutize_path( path )
    Pathname.new(path).realpath
  end

end
