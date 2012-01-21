module Puppet::Util::LogPaths
  # return the full path to us, for logging and rollback
  # some classes (e.g., FileTypeRecords) will have to override this
  def path
    @path ||= pathbuilder

    "/" + @path.join("/")
  end

  def source_descriptors
    descriptors = {}

    descriptors[:tags] = tags

    [:path, :file, :line].each do |param|
      next unless value = send(param)
      descriptors[param] = value
    end

    descriptors
  end

end

