#
#  Created by Luke Kanies on 2007-10-22.
#  Copyright (c) 2007. All rights reserved.

require 'find'
require 'puppet/file_serving'
require 'puppet/file_serving/metadata'

# Operate recursively on a path, returning a set of file paths.
class Puppet::FileServing::Fileset
    attr_reader :path, :ignore, :links
    attr_accessor :recurse

    # Return a list of all files in our fileset.  This is different from the
    # normal definition of find in that we support specific levels
    # of recursion, which means we need to know when we're going another
    # level deep, which Find doesn't do.
    def files
        files = perform_recursion

        # Now strip off the leading path, so each file becomes relative, and remove
        # any slashes that might end up at the beginning of the path.
        result = files.collect { |file| file.sub(%r{^#{Regexp.escape(@path)}/*}, '') }

        # And add the path itself.
        result.unshift(".")

        result
    end

    # Should we ignore this path?
    def ignore?(path)
        # 'detect' normally returns the found result, whereas we just want true/false.
        ! @ignore.detect { |pattern| File.fnmatch?(pattern, path) }.nil?
    end

    def ignore=(values)
        values = [values] unless values.is_a?(Array)
        @ignore = values
    end

    def initialize(path, options = {})
        raise ArgumentError.new("Fileset paths must be fully qualified") unless path =~ /^#{::File::SEPARATOR}/

        @path = path

        # Set our defaults.
        @ignore = []
        @links = :manage
        @recurse = false

        options.each do |option, value|
            method = option.to_s + "="
            begin
                send(method, value)
            rescue NoMethodError
                raise ArgumentError, "Invalid option '%s'" % option
            end
        end

        raise ArgumentError.new("Fileset paths must exist") unless stat = stat(path)
    end

    def links=(links)
        links = links.intern if links.is_a?(String)
        raise(ArgumentError, "Invalid :links value '%s'" % links) unless [:manage, :follow].include?(links)
        @links = links
        @stat_method = links == :manage ? :lstat : :stat
    end

    # Should we recurse further?  This is basically a single
    # place for all of the logic around recursion.
    def recurse?(depth)
        # If recurse is true, just return true
        return true if self.recurse == true

        # Return false if the value is false or zero.
        return false if [false, 0].include?(self.recurse)

        # Return true if our current depth is less than the allowed recursion depth.
        return true if self.recurse.is_a?(Fixnum) and depth <= self.recurse

        # Else, return false.
        return false
    end
    
    private

    # Pull the recursion logic into one place.  It's moderately hairy, and this
    # allows us to keep the hairiness apart from what we do with the files.
    def perform_recursion
        # Start out with just our base directory.
        current_dirs = [@path]

        next_dirs = []

        depth = 1

        result = []
        return result unless recurse?(depth)

        while dir_path = current_dirs.shift or ((depth += 1) and recurse?(depth) and current_dirs = next_dirs and next_dirs = [] and dir_path = current_dirs.shift)
            next unless stat = stat(dir_path)
            next unless stat.directory?

            Dir.entries(dir_path).each do |file_path|
                next if [".", ".."].include?(file_path)

                # Note that this also causes matching directories not
                # to be recursed into.
                next if ignore?(file_path)

                # Add it to our list of files to return
                result << File.join(dir_path, file_path)

                # And to our list of files/directories to iterate over.
                next_dirs << File.join(dir_path, file_path)
            end
        end

        return result
    end
    public
    # Stat a given file, using the links-appropriate method.
    def stat(path)
        unless defined?(@stat_method)
            @stat_method = self.links == :manage ? :lstat : :stat
        end

        begin
            return File.send(@stat_method, path)
        rescue
            # If this happens, it is almost surely because we're
            # trying to manage a link to a file that does not exist.
            return nil
        end
    end
end
