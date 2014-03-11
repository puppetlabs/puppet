require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/compiler'

class Puppet::Resource::Catalog::StaticCompiler < Puppet::Resource::Catalog::Compiler

  desc %q{Compiles catalogs on demand using the optional static compiler. This
    functions similarly to the normal compiler, but it replaces puppet:/// file
    URLs with explicit metadata and file content hashes, expecting puppet agent
    to fetch the exact specified content from the filebucket. This guarantees
    that a given catalog will always result in the same file states. It also
    decreases catalog application time and fileserver load, at the cost of
    increased compilation time.

    This terminus works today, but cannot be used without additional
    configuration. Specifically:

    * You must create a special filebucket resource --- with the title `puppet`
      and the `path` attribute set to `false` --- in site.pp or somewhere else
      where it will be added to every node's catalog. Using `puppet` as the title
      is mandatory; the static compiler treats this title as magical.

          filebucket { puppet:
            path => false,
          }

    * You must set `catalog_terminus = static_compiler` in the puppet
      master's puppet.conf.
    * The puppet master's auth.conf must allow authenticated nodes to access the
      `file_bucket_file` endpoint. This is enabled by default (see the
      `path /file` rule), but if you have made your auth.conf more restrictive,
      you may need to re-enable it.)
    * If you are using multiple puppet masters, you must configure load balancer
      affinity for agent nodes. This is because puppet masters other than the one
      that compiled a given catalog may not have stored the required file contents
      in their filebuckets.}

  def find(request)
    return nil unless catalog = super

    raise "Did not get catalog back" unless catalog.is_a?(model)

    catalog.resources.find_all { |res| res.type == "File" }.each do |resource|
      next unless source = resource[:source]
      next unless source =~ /^puppet:/

      file = resource.to_ral

      if file.recurse?
        add_children(request.key, catalog, resource, file)
      else
        find_and_replace_metadata(request.key, resource, file)
      end
    end

    catalog
  end

  # Take a resource with a fileserver based file source remove the source
  # parameter, and insert the file metadata into the resource.
  #
  # This method acts to do the fileserver metadata retrieval in advance, while
  # the file source is local and doesn't require an HTTP request. It retrieves
  # the file metadata for a given file resource, removes the source parameter
  # from the resource, inserts the metadata into the file resource, and uploads
  # the file contents of the source to the file bucket.
  #
  # @param host [String] The host name of the node requesting this catalog
  # @param resource [Puppet::Resource] The resource to replace the metadata in
  # @param file [Puppet::Type::File] The file RAL associated with the resource
  def find_and_replace_metadata(host, resource, file)
    # We remove URL info from it, so it forces a local copy
    # rather than routing through the network.
    # Weird, but true.
    newsource = file[:source][0].sub("puppet:///", "")
    file[:source][0] = newsource

    raise "Could not get metadata for #{resource[:source]}" unless metadata = file.parameter(:source).metadata

    replace_metadata(host, resource, metadata)
  end

  # Rewrite a given file resource with the metadata from a fileserver based file
  #
  # This performs the actual metadata rewrite for the given file resource and
  # uploads the content of the source file to the filebucket.
  #
  # @param host [String] The host name of the node requesting this catalog
  # @param resource [Puppet::Resource] The resource to add the metadata to
  # @param metadata [Puppet::FileServing::Metadata] The metadata of the given fileserver based file
  def replace_metadata(host, resource, metadata)
    [:mode, :owner, :group].each do |param|
      resource[param] ||= metadata.send(param)
    end

    resource[:ensure] = metadata.ftype
    if metadata.ftype == "file"
      unless resource[:content]
        resource[:content] = metadata.checksum
        resource[:checksum] = metadata.checksum_type
      end
    end

    store_content(resource) if resource[:ensure] == "file"
    old_source = resource.delete(:source)
    Puppet.info "Metadata for #{resource} in catalog for '#{host}' added from '#{old_source}'"
  end

  # Generate children resources for a recursive file and add them to the catalog.
  #
  # @param host [String] The host name of the node requesting this catalog
  # @param catalog [Puppet::Resource::Catalog]
  # @param resource [Puppet::Resource]
  # @param file [Puppet::Type::File] The file RAL associated with the resource
  def add_children(host, catalog, resource, file)
    file = resource.to_ral

    children = get_child_resources(host, catalog, resource, file)

    remove_existing_resources(children, catalog)

    children.each do |name, res|
      catalog.add_resource res
      catalog.add_edge(resource, res)
    end
  end

  # Given a recursive file resource, recursively generate its children resources
  #
  # @param host [String] The host name of the node requesting this catalog
  # @param catalog [Puppet::Resource::Catalog]
  # @param resource [Puppet::Resource]
  # @param file [Puppet::Type::File] The file RAL associated with the resource
  #
  # @return [Array<Puppet::Resource>] The recursively generated File resources for the given resource
  def get_child_resources(host, catalog, resource, file)
    sourceselect = file[:sourceselect]
    children = {}

    source = resource[:source]

    # This is largely a copy of recurse_remote in File
    total = file[:source].collect do |source|
      next unless result = file.perform_recursion(source)
      return if top = result.find { |r| r.relative_path == "." } and top.ftype != "directory"
      result.each { |data| data.source = "#{source}/#{data.relative_path}" }
      break result if result and ! result.empty? and sourceselect == :first
      result
    end.flatten.compact

    # This only happens if we have sourceselect == :all
    unless sourceselect == :first
      found = []
      total.reject! do |data|
        result = found.include?(data.relative_path)
        found << data.relative_path unless found.include?(data.relative_path)
        result
      end
    end

    total.each do |meta|
      # This is the top-level parent directory
      if meta.relative_path == "."
        replace_metadata(host, resource, meta)
        next
      end
      children[meta.relative_path] ||= Puppet::Resource.new(:file, File.join(file[:path], meta.relative_path))

      # I think this is safe since it's a URL, not an actual file
      children[meta.relative_path][:source] = source + "/" + meta.relative_path
      resource.each do |param, value|
        # These should never be passed to our children.
        unless [:parent, :ensure, :recurse, :recurselimit, :target, :alias, :source].include? param
          children[meta.relative_path][param] = value
        end
      end
      replace_metadata(host, children[meta.relative_path], meta)
    end

    children
  end

  # Remove any file resources in the catalog that will be duplicated by the
  # given file resources.
  #
  # @param children [Array<Puppet::Resource>]
  # @param catalog [Puppet::Resource::Catalog]
  def remove_existing_resources(children, catalog)
    existing_names = catalog.resources.collect { |r| r.to_s }
    both = (existing_names & children.keys).inject({}) { |hash, name| hash[name] = true; hash }
    both.each { |name| children.delete(name) }
  end

  # Retrieve the source of a file resource using a fileserver based source and
  # upload it to the filebucket.
  #
  # @param resource [Puppet::Resource]
  def store_content(resource)
    @summer ||= Object.new
    @summer.extend(Puppet::Util::Checksums)

    type = @summer.sumtype(resource[:content])
    sum = @summer.sumdata(resource[:content])

    if Puppet::FileBucket::File.indirection.find("#{type}/#{sum}")
      Puppet.info "Content for '#{resource[:source]}' already exists"
    else
      Puppet.info "Storing content for source '#{resource[:source]}'"
      content = Puppet::FileServing::Content.indirection.find(resource[:source])
      file = Puppet::FileBucket::File.new(content.content)
      Puppet::FileBucket::File.indirection.save(file)
    end
  end
end
