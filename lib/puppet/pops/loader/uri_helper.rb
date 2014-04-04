module Puppet::Pops::Loader::UriHelper
  # Raises an exception if specified gem can not be located
  #
  def path_for_uri(uri, subdir='lib')
    case uri.scheme
    when "gem"
      begin
        spec = Gem::Specification.find_by_name(uri.hostname)
        # if path given append that, else append given subdir
        File.join(spec.gem_dir, uri.path.empty?() ? subdir : uri.path)
      rescue StandardError => e
        raise "TODO TYPE: Failed to located gem #{uri}. #{e.message}"
      end
    when "file"
      File.join(uri.path, subdir)
    when nil
      File.join(uri.path, subdir)
    else
      raise "Not a valid scheme for a loader: #{uri.scheme}. Use a 'file:' (or just a path), or 'gem://gemname[/path]"
    end
  end
end
