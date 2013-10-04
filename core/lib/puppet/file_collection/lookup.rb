require 'puppet/file_collection'

module Puppet::FileCollection::Lookup
  # Yeah, this is all the external interface that was added to the folks who
  # included this really was.  Thankfully.
  #
  # See the comments in `puppet/file_collection.rb` for the annotated version,
  # or just port your code away from this by adding the accessors on your own.
  attr_accessor :line, :file
end
