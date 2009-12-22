#
#  Created by Luke Kanies on 2007-10-22.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving'

# The base class for Content and Metadata; provides common
# functionality like the behaviour around links.
class Puppet::FileServing::Base
    # This is for external consumers to store the source that was used
    # to retrieve the metadata.
    attr_accessor :source

    # Does our file exist?
    def exist?
        begin
            stat
            return true
        rescue => detail
            return false
        end
    end

    # Return the full path to our file.  Fails if there's no path set.
    def full_path(dummy_argument=:work_arround_for_ruby_GC_bug)
        (if relative_path.nil? or relative_path == "" or relative_path == "."
            path
        else
            File.join(path, relative_path)
        end).gsub(%r{/+}, "/")
    end

    def initialize(path, options = {})
        self.path = path
        @links = :manage

        options.each do |param, value|
            begin
                send param.to_s + "=", value
            rescue NoMethodError
                raise ArgumentError, "Invalid option %s for %s" % [param, self.class]
            end
        end
    end

    # Determine how we deal with links.
    attr_reader :links
    def links=(value)
        value = value.to_sym
        value = :manage if value == :ignore
        raise(ArgumentError, ":links can only be set to :manage or :follow") unless [:manage, :follow].include?(value)
        @links = value
    end

    # Set our base path.
    attr_reader :path
    def path=(path)
        raise ArgumentError.new("Paths must be fully qualified") unless path =~ /^#{::File::SEPARATOR}/
        @path = path
    end

    # Set a relative path; this is used for recursion, and sets
    # the file's path relative to the initial recursion point.
    attr_reader :relative_path
    def relative_path=(path)
        raise ArgumentError.new("Relative paths must not be fully qualified") if path =~ /^#{::File::SEPARATOR}/
        @relative_path = path
    end

    # Stat our file, using the appropriate link-sensitive method.
    def stat
        unless defined?(@stat_method)
            @stat_method = self.links == :manage ? :lstat : :stat
        end
        File.send(@stat_method, full_path())
    end

    def to_pson_data_hash
        {
            # No 'document_type' since we don't send these bare
            'data'       => {
                'path'          => @path,
                'relative_path' => @relative_path,
                'links'         => @links
                },
            'metadata' => {
                'api_version' => 1
                }
       }
    end

end
