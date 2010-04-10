require 'puppet/file_bucket'
require 'puppet/indirector'

class Puppet::FileBucket::File
    # This class handles the abstract notion of a file in a filebucket.
    # There are mechanisms to save and load this file locally and remotely in puppet/indirector/filebucketfile/*
    # There is a compatibility class that emulates pre-indirector filebuckets in Puppet::FileBucket::Dipper
    extend Puppet::Indirector
    require 'puppet/file_bucket/file/indirection_hooks'
    indirects :file_bucket_file, :terminus_class => :file, :extend => Puppet::FileBucket::File::IndirectionHooks

    attr :path, true
    attr :paths, true
    attr :contents, true
    attr :checksum_type
    attr :bucket_path, true

    def self.default_checksum_type
        :md5
    end

    def initialize( contents, options = {} )
        @contents      = contents
        @bucket_path   = options[:bucket_path]
        @path          = options[:path]
        @paths         = options[:paths] || []
        @checksum      = options[:checksum]
        @checksum_type = options[:checksum_type] || self.class.default_checksum_type

        yield(self) if block_given?

        validate!
    end

    def validate!
        digest_class( @checksum_type ) # raises error on bad types
        raise ArgumentError, 'contents must be a string' unless @contents.is_a?(String)
        validate_checksum(@checksum) if @checksum
    end

    def contents=(contents)
        raise "You may not change the contents of a FileBucket File" if @contents
        @contents = contents
    end

    def checksum=(checksum)
        validate_checksum(checksum)
        self.checksum_type = checksum # this grabs the prefix only
        @checksum = checksum
    end

    def validate_checksum(new_checksum)
        unless new_checksum == checksum_of_type(new_checksum)
            raise Puppet::Error, "checksum does not match contents"
        end
    end

    def checksum
        @checksum ||= checksum_of_type(checksum_type)
    end

    def checksum_of_type( type )
        type = checksum_type( type ) # strip out data segment if there is one
        type.to_s + ":" + digest_class(type).hexdigest(@contents)
    end

    def checksum_type=( new_checksum_type )
        @checksum = nil
        @checksum_type = checksum_type(new_checksum_type)
    end

    def checksum_type(checksum = @checksum_type)
        checksum.to_s.split(':',2)[0].to_sym
    end

    def checksum_data(new_checksum = self.checksum)
        new_checksum.split(':',2)[1]
    end

    def checksum_data=(new_data)
        self.checksum = "#{checksum_type}:#{new_data}"
    end

    def digest_class(type = nil)
        case checksum_type(type)
        when :md5  : require 'digest/md5'  ; Digest::MD5
        when :sha1 : require 'digest/sha1' ; Digest::SHA1
        else
            raise ArgumentError, "not a known checksum type: #{checksum_type(type)}"
        end
    end

    def to_s
        contents
    end

    def name
        [checksum_type, checksum_data, path].compact.join('/')
    end

    def name=(name)
        self.checksum_type, self.checksum_data, self.path = name.split('/',3)
    end

    def conflict_check?
        true
    end

    def self.from_s( contents )
        self.new( contents )
    end

    def to_pson
        hash = { "contents" => contents }
        hash["path"] = @path if @path
        hash.to_pson
    end

    def self.from_pson( pson )
        self.new( pson["contents"], :path => pson["path"] )
    end

end
