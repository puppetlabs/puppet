# Setup Tips #

To get a shared filesystem:

    net use Z: "\\vmware-host\Shared Folders" /persistent:yes

# Common Issues #

I seem to be getting this a lot downloading files:

    undefined method `zero?' for nil:NilClass

This appears to be from the call to the progress bar method having nil content
from the response.content\_length here:

    % ack with_progress_bar
    rake/contrib/uri_ext.rb
    161:    #   with_progress_bar(enable, file_name, size) { |progress| ... }
    171:    def with_progress_bar(enable, file_name, size) #:nodoc:
    254:            with_progress_bar options[:progress], path.split('/').last, response.content_length do |progress|
