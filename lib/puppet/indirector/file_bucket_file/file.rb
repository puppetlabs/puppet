require 'puppet/indirector/code'
require 'puppet/file_bucket/file'
require 'puppet/util/checksums'
require 'puppet/util/diff'
require 'fileutils'

module Puppet::FileBucketFile
  class File < Puppet::Indirector::Code
    include Puppet::Util::Checksums
    include Puppet::Util::Diff

    desc "Store files in a directory set based on their checksums."

    def find(request)
      request.options[:bucket_path] ||= Puppet[:bucketdir]
      # If filebucket mode is 'list'
      if request.options[:list_all]
        return nil unless ::File.exists?(request.options[:bucket_path])
        return list(request)
      end
      checksum, files_original_path = request_to_checksum_and_path(request)
      contents_file = path_for(request.options[:bucket_path], checksum, 'contents')
      paths_file = path_for(request.options[:bucket_path], checksum, 'paths')

      if Puppet::FileSystem.exist?(contents_file) && matches(paths_file, files_original_path)
        if request.options[:diff_with]
          other_contents_file = path_for(request.options[:bucket_path], request.options[:diff_with], 'contents')
          raise _("could not find diff_with %{diff}") % { diff: request.options[:diff_with] } unless Puppet::FileSystem.exist?(other_contents_file)
          raise _("Unable to diff on this platform") unless Puppet[:diff] != ""
          return diff(Puppet::FileSystem.path_string(contents_file), Puppet::FileSystem.path_string(other_contents_file))
        else
          #TRANSLATORS "FileBucket" should not be translated
          Puppet.info _("FileBucket read %{checksum}") % { checksum: checksum }
          model.new(Puppet::FileSystem.binread(contents_file))
        end
      else
        nil
      end
    end

    def list(request)
      if request.remote?
        raise Puppet::Error, _("Listing remote file buckets is not allowed")
      end

      fromdate = request.options[:fromdate] || "0:0:0 1-1-1970"
      todate = request.options[:todate] || Time.now.strftime("%F %T")
      begin
        to = Time.parse(todate)
      rescue ArgumentError
        raise Puppet::Error, _("Error while parsing 'todate'")
      end
      begin
        from = Time.parse(fromdate)
      rescue ArgumentError
        raise Puppet::Error, _("Error while parsing 'fromdate'")
      end
      # Setting hash's default value to [], needed by the following loop
      bucket = Hash.new {[]}
      msg = ""
      # Get all files with mtime between 'from' and 'to'
      Pathname.new(request.options[:bucket_path]).find { |item|
        if item.file? and item.basename.to_s == "paths"
          filenames = item.read.strip.split("\n")
          filestat = Time.parse(item.stat.mtime.to_s)
          if from <= filestat and filestat <= to
            filenames.each do |filename|
              bucket[filename] += [[ item.stat.mtime , item.parent.basename ]]
            end
          end
        end
      }
      # Sort the results
      bucket.each { |filename, contents|
        contents.sort_by! do |item|
          # NOTE: Ruby 2.4 may reshuffle item order even if the keys in sequence are sorted already
          item[0]
        end
      }
      # Build the output message. Sorted by names then by dates
      bucket.sort.each { |filename,contents|
        contents.each { |mtime, chksum|
          date = mtime.strftime("%F %T")
          msg += "#{chksum} #{date} #{filename}\n"
        }
      }
      return model.new(msg)
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
      # Puppet will have already written the paths_file in the systems encoding
      # given its possible that request.options[:bucket_path] or Puppet[:bucketdir]
      # contained characters in an encoding that are not represented the
      # same way when the bytes are decoded as UTF-8, continue using system encoding
      Puppet::FileSystem.open(paths_file, 0640, 'a+:external') do |f|
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

    # @param bucket_file [Puppet::FileBucket::File] IO object representing
    #   content to back up
    # @param files_original_path [String] Path to original source file on disk
    # @param contents_file [Pathname] Opaque file path to intended backup
    #   location
    # @param paths_file [Pathname] Opaque file path to file containing source
    #   file paths on disk
    # @return [void]
    # @raise [Puppet::FileBucket::BucketError] on possible sum collision between
    #   existing and new backup
    # @api private
    def save_to_disk(bucket_file, files_original_path, contents_file, paths_file)
      Puppet::Util.withumask(0007) do
        unless Puppet::FileSystem.dir_exist?(paths_file)
          Puppet::FileSystem.dir_mkpath(paths_file)
        end

        # Puppet will have already written the paths_file in the systems encoding
        # given its possible that request.options[:bucket_path] or Puppet[:bucketdir]
        # contained characters in an encoding that are not represented the
        # same way when the bytes are decoded as UTF-8, continue using system encoding
        Puppet::FileSystem.exclusive_open(paths_file, 0640, 'a+:external') do |f|
          if Puppet::FileSystem.exist?(contents_file)
            if verify_identical_file(contents_file, bucket_file)
              #TRANSLATORS "FileBucket" should not be translated
              Puppet.info _("FileBucket got a duplicate file %{file_checksum}") % { file_checksum: bucket_file.checksum }
              # Don't touch the contents file on Windows, since we can't update the
              # mtime of read-only files there.
              if !Puppet::Util::Platform.windows?
                Puppet::FileSystem.touch(contents_file)
              end
            elsif contents_file_matches_checksum?(contents_file, bucket_file.checksum_data, bucket_file.checksum_type)
              # If the contents or sizes don't match, but the checksum does,
              # then we've found a conflict (potential hash collision).
              # Unlikely, but quite bad. Don't remove the file in case it's
              # needed, but ask the user to validate.
              # Note: Don't print the full path to the bucket file in the
              # exception to avoid disclosing file system layout on server.
              #TRANSLATORS "FileBucket" should not be translated
              Puppet.err(_("Unable to verify existing FileBucket backup at '%{path}'.") % { path: contents_file.to_path })
              raise Puppet::FileBucket::BucketError, _("Existing backup and new file have different content but same checksum, %{value}. Verify existing backup and remove if incorrect.") %
                { value: bucket_file.checksum }
            else
              # PUP-1334 If the contents_file exists but does not match its
              # checksum, our backup has been corrupted. Warn about overwriting
              # it, and proceed with new backup.
              Puppet.warning(_("Existing backup does not match its expected sum, %{sum}. Overwriting corrupted backup.") % { sum: bucket_file.checksum })
              copy_bucket_file_to_contents_file(contents_file, bucket_file)
            end
          else
            copy_bucket_file_to_contents_file(contents_file, bucket_file)
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
      raise ArgumentError, _("Unsupported checksum type %{checksum_type}") % { checksum_type: checksum_type.inspect } if checksum_type != Puppet[:digest_algorithm]
      expected = method(checksum_type + "_hex_length").call
      raise _("Invalid checksum %{checksum}") % { checksum: checksum.inspect } if checksum !~ /^[0-9a-f]{#{expected}}$/
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

    # @param contents_file [Pathname] Opaque file path to intended backup
    #   location
    # @param bucket_file [Puppet::FileBucket::File] IO object representing
    #   content to back up
    # @return [Boolean] whether the data in contents_file is of the same size
    #   and content as that in the bucket_file
    # @api private
    def verify_identical_file(contents_file, bucket_file)
      (bucket_file.to_binary.bytesize == Puppet::FileSystem.size(contents_file)) &&
        (bucket_file.stream() {|s| Puppet::FileSystem.compare_stream(contents_file, s) })
    end

    # @param contents_file [Pathname] Opaque file path to intended backup
    #   location
    # @param expected_checksum_data [String] expected value of checksum of type
    #   checksum_type
    # @param checksum_type [String] type of check sum of checksum_data, ie "md5"
    # @return [Boolean] whether the checksum of the contents_file matches the
    #   supplied checksum
    # @api private
    def contents_file_matches_checksum?(contents_file, expected_checksum_data, checksum_type)
      contents_file_checksum_data = Puppet::Util::Checksums.method(:"#{checksum_type}_file").call(contents_file.to_path)
      contents_file_checksum_data == expected_checksum_data
    end

    # @param contents_file [Pathname] Opaque file path to intended backup
    #   location
    # @param bucket_file [Puppet::FileBucket::File] IO object representing
    #   content to back up
    # @return [void]
    # @api private
    def copy_bucket_file_to_contents_file(contents_file, bucket_file)
      Puppet::Util.replace_file(contents_file, 0440) do |of|
        # PUP-1044 writes all of the contents
        bucket_file.stream() do |src|
          FileUtils.copy_stream(src, of)
        end
      end
    end

  end
end
