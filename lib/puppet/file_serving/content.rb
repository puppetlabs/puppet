#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/indirector'
require 'puppet/file_serving'

# A class that handles retrieving file contents.
# It only reads the file when its content is specifically
# asked for.
class Puppet::FileServing::Content
    extend Puppet::Indirector
    indirects :file_content, :terminus_class => :file

    attr_reader :path

    def content
        ::File.read(@path)
    end

    def initialize(path)
        raise ArgumentError.new("Files must be fully qualified") unless path =~ /^#{::File::SEPARATOR}/
        raise ArgumentError.new("Files must exist") unless FileTest.exists?(path)

        @path = path
    end

    # Just return the file contents as the yaml.  This allows us to
    # avoid escaping or any such thing.  LAK:FIXME Not really sure how
    # this will behave if the file contains yaml...  I think the far
    # side needs to understand that it's a plain string.
    def to_yaml
        content
    end
end
