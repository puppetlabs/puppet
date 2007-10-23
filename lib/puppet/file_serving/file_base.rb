#
#  Created by Luke Kanies on 2007-10-22.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving'

# The base class for Content and Metadata; provides common
# functionality like the behaviour around links.
class Puppet::FileServing::FileBase
    attr_accessor :path, :base_path

    def full_path(base = nil)
        base ||= base_path || raise(ArgumentError, "You must set or provide a base path")

        full = File.join(base, self.path)
    end

    def initialize(path, options = {})
        raise ArgumentError.new("Files must not be fully qualified") if path =~ /^#{::File::SEPARATOR}/

        @path = path
        @links = :manage

        options.each do |param, value|
            begin
                send param.to_s + "=", value
            rescue NoMethodError
                raise ArgumentError, "Invalid option %s for %s" % [param, self.class]
            end
        end
    end

    attr_reader :links
    def links=(value)
        raise(ArgumentError, ":links can only be set to :manage or :follow") unless [:manage, :follow].include?(value) 
        @links = value
    end

    # Stat our file, using the appropriate link-sensitive method.
    def stat(base = nil)
        unless defined?(@stat_method)
            @stat_method = self.links == :manage ? :lstat : :stat
        end
        File.send(@stat_method, full_path(base))
    end
end
