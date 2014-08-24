require 'puppet/indirector/code'
require 'puppet/file_bucket/file'
require 'puppet/util/checksums'
require 'fileutils'

module Puppet::FileBucketFile
  class File < Puppet::Indirector::Code
    include Puppet::Util::Checksums

    desc "Store files in a directory set based on their checksums."

    def find(request)
      checksum, files_original_path = request_to_checksum_and_path(request)
      contents_file = path_for(request.options[:bucket_path], checksum, 'contents')
      paths_file = path_for(request.options[:bucket_path], checksum, 'paths')

      if Puppet::FileSystem.exist?(contents_file) && matches(paths_file, files_original_path)
        if request.options[:diff_with]
          other_contents_file = path_for(request.options[:bucket_path], request.options[:diff_with], 'contents')
          raise "could not find diff_with #{request.options[:diff_with]}" unless Puppet::FileSystem.exist?(other_contents_file)
          return `diff #{Puppet::FileSystem.path_string(contents_file).inspect} #{Puppet::FileSystem.path_string(other_contents_file).inspect}`
        else
          Puppet.info "FileBucket read #{checksum}"
          model.new(Puppet::FileSystem.binread(contents_file))
        end
      else
        nil
      end
    end

    def head(request)
      checksum, files_original_path = request_to_checksum_and_path(request)
      contents_file = path_for(request.options[:bucket_path], checksum, 'contents')
      paths_file = path_for(request.options[:bucket_path], checksum, 'paths')

      Puppet::FileSystem.exist?(contents_file) && matches(paths_file, files_original_path)
    end

    def save(request)
      instance = request.instance
      _, files_original_path = request_to_checksum_and_path(request)
      contents_file = path_for(instance.bucket_path, instance.checksum_data, 'contents')
      paths_file = path_for(instance.bucket_path, instance.checksum_data, 'paths')

      save_to_disk(instance, files_original_path, contents_file, paths_file)

      # don't echo the request content back to the agent
      model.new('')
    end

    def validate_key(request)
      # There are no ACLs on filebucket files so validating key is not important
    end

    private

    # @param paths_file [Object] Opaque file path
    # @param files_original_path [String]
    #
    def matches(paths_file, files_original_path)
      Puppet::FileSystem.open(paths_file, 0640, 'a+') do |f|
        path_match(f, files_original_path)
      end
    end

    def path_match(file_handle, files_original_path)
      return true unless files_original_path # if no path was provided, it's a match
      file_handle.rewind
      file_handle.each_line do |line|
        return true if line.chomp == files_original_path
      end
      return false
    end

    # @param contents_file [Object] Opaque file path
    # @param paths_file [Object] Opaque file path
    #
    def save_to_disk(bucket_file, files_original_path, contents_file, paths_file)
      Puppet::Util.withumask(0007) do
        unless Puppet::FileSystem.dir_exist?(paths_file)
          Puppet::FileSystem.dir_mkpath(paths_file)
        end

        Puppet::FileSystem.exclusive_open(paths_file, 0640, 'a+') do |f|
          if Puppet::FileSystem.exist?(contents_file)
            verify_identical_file!(contents_file, bucket_file)
            Puppet::FileSystem.touch(contents_file)
          else
            Puppet::FileSystem.open(contents_file, 0440, 'wb') do |of|
              # PUP-1044 writes all of the contents
              bucket_file.stream() do |src|
                FileUtils.copy_stream(src, of)
              end
            end
          end

          unless path_match(f, files_original_path)
            f.seek(0, IO::SEEK_END)
            f.puts(files_original_path)
          end
        end
      end
    end

    def request_to_checksum_and_path(request)
      checksum_type, checksum, path = request.key.split(/\//, 3)
      if path == '' # Treat "md5/<checksum>/" like "md5/<checksum>"
        path = nil
      end
      raise ArgumentError, "Unsupported checksum type #{checksum_type.inspect}" if checksum_type != Puppet[:digest_algorithm]
      expected = method(checksum_type + "_hex_length").call
      raise "Invalid checksum #{checksum.inspect}" if checksum !~ /^[0-9a-f]{#{expected}}$/
      [checksum, path]
    end

    # @return [Object] Opaque path as constructed by the Puppet::FileSystem
    #
    def path_for(bucket_path, digest, subfile = nil)
      bucket_path ||= Puppet[:bucketdir]

      dir     = ::File.join(digest[0..7].split(""))
      basedir = ::File.join(bucket_path, dir, digest)

      Puppet::FileSystem.pathname(subfile ? ::File.join(basedir, subfile) : basedir)
    end

    # @param contents_file [Object] Opaque file path
    # @param bucket_file [IO]
    def verify_identical_file!(contents_file, bucket_file)
      if bucket_file.size == Puppet::FileSystem.size(contents_file)
        if bucket_file.stream() {|s| Puppet::FileSystem.compare_stream(contents_file, s) }
          Puppet.info "FileBucket got a duplicate file #{bucket_file.checksum}"
          return
        end
      end

      # If the contents or sizes don't match, then we've found a conflict.
      # Unlikely, but quite bad.
      raise Puppet::FileBucket::BucketError, "Got passed new contents for sum #{bucket_file.checksum}"
    end
  end
end
