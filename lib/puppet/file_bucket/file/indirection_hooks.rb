require 'puppet/file_bucket/file'

# This module is used to pick the appropriate terminus
# in filebucket indirections.
module Puppet::FileBucket::File::IndirectionHooks
    def select_terminus(request)
        return :rest if request.protocol == 'https'
        return Puppet::FileBucket::File.indirection.terminus_class
    end
end
