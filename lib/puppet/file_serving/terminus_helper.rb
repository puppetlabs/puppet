require 'puppet/file_serving'
require 'puppet/file_serving/fileset'

# Define some common methods for FileServing termini.
module Puppet::FileServing::TerminusHelper
  # Create model instance for a file in a file server.
  def path2instance(request, path, options = {})
    result = model.new(path, :relative_path => options[:relative_path])
    result.checksum_type = request.options[:checksum_type] if request.options[:checksum_type]
    result.links = request.options[:links] if request.options[:links]

    # :ignore_source_permissions is here pending investigation in PUP-3906.
    if options[:ignore_source_permissions]
      result.collect
    else
      result.collect(request.options[:source_permissions])
    end
    result
  end

  # Create model instances for all files in a fileset.
  def path2instances(request, *paths)
    filesets = paths.collect do |path|
      # Filesets support indirector requests as an options collection
      Puppet::FileServing::Fileset.new(path, request)
    end

    Puppet::FileServing::Fileset.merge(*filesets).collect do |file, base_path|
      path2instance(request, base_path, :ignore_source_permissions => true, :relative_path => file)
    end
  end
end
