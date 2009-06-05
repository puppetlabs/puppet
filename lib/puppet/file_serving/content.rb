#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/base'
require 'puppet/file_serving/indirection_hooks'

# A class that handles retrieving file contents.
# It only reads the file when its content is specifically
# asked for.
class Puppet::FileServing::Content < Puppet::FileServing::Base
    extend Puppet::Indirector
    indirects :file_content, :extend => Puppet::FileServing::IndirectionHooks

    attr_writer :content

    def self.supported_formats
        [:raw]
    end

    def self.from_raw(content)
        instance = new("/this/is/a/fake/path")
        instance.content = content
        instance
    end

    # Collect our data.
    def collect
        return if stat.ftype == "directory"
        content
    end

    # Read the content of our file in.
    def content
        unless defined?(@content) and @content
            # This stat can raise an exception, too.
            raise(ArgumentError, "Cannot read the contents of links unless following links") if stat().ftype == "symlink"

            @content = ::File.read(full_path())
        end
        @content
    end

    def to_raw
        content
    end
end
