require 'puppet/file_serving'
require 'puppet/file_serving/fileset'

# Define some common methods for FileServing termini.

module Puppet::FileServing::TerminusHelper
  # Create model instance for a file in a file server.
  def path2instance(request, path, options = {})
    result = model.new(path, :relative_path => options[:relative_path])
    result.links = request.options[:links] if request.options[:links]

    result.checksum_type = request.options[:checksum_type] if request.options[:checksum_type]
    result.source_permissions = request.options[:source_permissions] if request.options[:source_permissions]

    result.collect

    result
  end

  # Create model instances for all files in a fileset.
  def path2instances(request, *paths)
    filesets = paths.collect do |path|
      # Filesets support indirector requests as an options collection
      Puppet::FileServing::Fileset.new(path, request)
    end

    Puppet::FileServing::Fileset.merge(*filesets).collect do |file, base_path|
      path2instance(request, base_path, :relative_path => file)
    end
  end
end
