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

      if contents_file.exist? && matches(paths_file, files_original_path)
        if request.options[:diff_with]
          other_contents_file = path_for(request.options[:bucket_path], request.options[:diff_with], 'contents')
          raise "could not find diff_with #{request.options[:diff_with]}" unless other_contents_file.exist?
          return `diff #{contents_file.path.to_s.inspect} #{other_contents_file.path.to_s.inspect}`
        else
          Puppet.info "FileBucket read #{checksum}"
          model.new(contents_file.binread)
        end
      else
        nil
      end
    end

    def head(request)
      checksum, files_original_path = request_to_checksum_and_path(request)
      contents_file = path_for(request.options[:bucket_path], checksum, 'contents')
      paths_file = path_for(request.options[:bucket_path], checksum, 'paths')

      contents_file.exist? && matches(paths_file, files_original_path)
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

    def matches(paths_file, files_original_path)
      paths_file.open(0640, 'a+') do |f|
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

    def save_to_disk(bucket_file, files_original_path, contents_file, paths_file)
      Puppet::Util.withumask(0007) do
        unless paths_file.dir.exist?
          paths_file.dir.mkpath
        end

        paths_file.exclusive_open(0640, 'a+') do |f|
          if contents_file.exist?
            verify_identical_file!(contents_file, bucket_file)
            contents_file.touch
          else
            contents_file.open(0440, 'wb') do |of|
              of.write(bucket_file.contents)
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
      raise "Unsupported checksum type #{checksum_type.inspect}" if checksum_type != 'md5'
      raise "Invalid checksum #{checksum.inspect}" if checksum !~ /^[0-9a-f]{32}$/
      [checksum, path]
    end

    def path_for(bucket_path, digest, subfile = nil)
      bucket_path ||= Puppet[:bucketdir]

      dir     = ::File.join(digest[0..7].split(""))
      basedir = ::File.join(bucket_path, dir, digest)

      Puppet::FileSystem::File.new(subfile ? ::File.join(basedir, subfile) : basedir)
    end

    def verify_identical_file!(contents_file, bucket_file)
      if bucket_file.contents.size == contents_file.size
        if contents_file.compare_stream(bucket_file.stream)
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
