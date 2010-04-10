require 'puppet/indirector/code'
require 'puppet/file_bucket/file'

module Puppet::FileBucketFile
    class File < Puppet::Indirector::Code
        desc "Store files in a directory set based on their checksums."

        def initialize
            Puppet.settings.use(:filebucket)
        end

        def find( request )
            checksum, path = request_to_checksum_and_path( request )
            return find_by_checksum( checksum, request.options )
        end

        def save( request )
            checksum, path = request_to_checksum_and_path( request )

            instance = request.instance
            instance.checksum = checksum if checksum
            instance.path = path if path

            save_to_disk(instance)
            instance.to_s
        end

        private

        def find_by_checksum( checksum, options )
            model.new( nil, :checksum => checksum ) do |bucket_file|
                bucket_file.bucket_path = options[:bucket_path]
                filename = contents_path_for( bucket_file )

                if ! ::File.exist? filename
                    return nil
                end

                begin
                    contents = ::File.read filename
                    Puppet.info "FileBucket read #{bucket_file.checksum}"
                rescue RuntimeError => e
                    raise Puppet::Error, "file could not be read: #{e.message}"
                end

                if ::File.exist?(paths_path_for( bucket_file) )
                    ::File.open(paths_path_for( bucket_file) ) do |f|
                        bucket_file.paths = f.readlines.map { |l| l.chomp }
                    end
                end

                bucket_file.contents = contents
            end
        end

        def save_to_disk( bucket_file )
            # If the file already exists, just return the md5 sum.
            if ::File.exist?(contents_path_for( bucket_file) )
                verify_identical_file!(bucket_file)
            else
                # Make the directories if necessary.
                unless ::File.directory?( path_for( bucket_file) )
                    Puppet::Util.withumask(0007) do
                        ::FileUtils.mkdir_p( path_for( bucket_file) )
                    end
                end

                Puppet.info "FileBucket adding #{bucket_file.path} (#{bucket_file.checksum_data})"

                # Write the file to disk.
                Puppet::Util.withumask(0007) do
                    ::File.open(contents_path_for(bucket_file), ::File::WRONLY|::File::CREAT, 0440) do |of|
                        of.print bucket_file.contents
                    end
                end
            end

            save_path_to_paths_file(bucket_file)
            return bucket_file.checksum_data
        end

        def request_to_checksum_and_path( request )
            checksum_type, checksum, path = request.key.split(/[:\/]/, 3)
            return nil if checksum_type.to_s == ""
            return [ checksum_type + ":" + checksum, path ]
        end

        def path_for(bucket_file, subfile = nil)
            bucket_path = bucket_file.bucket_path || Puppet[:bucketdir]
            digest      = bucket_file.checksum_data

            dir     = ::File.join(digest[0..7].split(""))
            basedir = ::File.join(bucket_path, dir, digest)

            return basedir unless subfile
            return ::File.join(basedir, subfile)
        end

        def contents_path_for(bucket_file)
            path_for(bucket_file, "contents")
        end

        def paths_path_for(bucket_file)
            path_for(bucket_file, "paths")
        end

        def content_check?
            true
        end

        # If conflict_check is enabled, verify that the passed text is
        # the same as the text in our file.
        def verify_identical_file!(bucket_file)
            return unless content_check?
            disk_contents = ::File.read(contents_path_for(bucket_file))

            # If the contents don't match, then we've found a conflict.
            # Unlikely, but quite bad.
            if disk_contents != bucket_file.contents
                raise Puppet::FileBucket::BucketError, "Got passed new contents for sum #{bucket_file.checksum}", caller
            else
                Puppet.info "FileBucket got a duplicate file #{bucket_file.path} (#{bucket_file.checksum})"
            end
        end

        def save_path_to_paths_file(bucket_file)
            return unless bucket_file.path

            # check for dupes
            if ::File.exist?(paths_path_for( bucket_file) )
                ::File.open(paths_path_for( bucket_file) ) do |f|
                    return if f.readlines.collect { |l| l.chomp }.include?(bucket_file.path)
                end
            end

            # if it's a new file, or if our path isn't in the file yet, add it
            ::File.open(paths_path_for(bucket_file), ::File::WRONLY|::File::CREAT|::File::APPEND) do |of|
                of.puts bucket_file.path
            end
        end

    end
end
