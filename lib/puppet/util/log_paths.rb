#  Created by Luke Kanies on 2007-07-04.
#  Copyright (c) 2007. All rights reserved.

module Puppet::Util::LogPaths
    # return the full path to us, for logging and rollback
    # some classes (e.g., FileTypeRecords) will have to override this
    def path
        unless defined? @path
            @path = pathbuilder
        end

        return "/" + @path.join("/")
    end

    def source_descriptors
        descriptors = {}

        descriptors[:tags] = tags

        [:path, :file, :line, :version].each do |param|
            next unless value = send(param)
            descriptors[param] = value
        end

        return descriptors
    end

end

