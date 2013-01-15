module Puppet::ModuleTool::Shared

  include Puppet::ModuleTool::Errors

  def safe_semver(version)
    SemVer.new(version) rescue SemVer::MIN
  end

  def safe_range(constraint)
    SemVer[constraint] rescue SemVer['>= 0.0.0']
  end

  def is_exact(range)
    return false if range.nil?
    unless range.is_a?(Range)
      begin
        range = SemVer[range]
      rescue
        return false
      end
    end
    b = range.begin
    e = range.end

    return b.major == e.major && b.minor == e.minor && b.tiny == e.tiny && b.special == '-' && e.special == ''
  end

  def get_local_constraints
    # hash of installed module releases
    @installed  = Hash.new { |h,k| h[k] = [] }
    # hash of constraints on each individual module found in all already installed
    # module releases
    @conditions = Hash.new { |h,k| h[k] = [] }

    # create a release structure for each already installed module release
    @environment.modules_by_path.values.flatten.each do |mod|
      module_name = (mod.forge_name || mod.name).tr('/', '-')
      version = mod.version

      release = {
        :module_name      => module_name,
        :version          => version,
        :semver           => safe_semver(version),
        # this is what distinguishes an already installed module release
        # from a release available in a local tarball or at Forge;
        # it is a reference to an instance of the Puppet::Module class
        :module           => mod,
        :dependencies     => []
      }

      dependencies = release[:dependencies]
      (mod.dependencies || []).each do |dependency|
        name, constraint = dependency['name'], dependency['version_requirement']
        name = name.tr('/', '-')

        dependency = {
          :source         => release,
          :target         => name,
          :constraint     => constraint,
          :range          => safe_range(constraint)
        }

        dependencies << dependency
        @conditions[name] << dependency
      end

      # remember the installed release
      @installed[module_name] << release
    end
  end

  # create a release structure for a local tarball found in the specified file
  # containing the specified metadata
  def get_release(metadata, file)
    return nil if metadata.nil?

    module_name = metadata['name'] 
    version = metadata['version']

    release = {
      :module_name      => module_name,
      :version          => version,
      :semver           => safe_semver(version),
      :url              => 'file:' << file,
      :previous         => @installed[module_name].first,
      :dependencies     => []
    }

    dependencies = release[:dependencies]
    (metadata['dependencies'] || []).each do |dependency|
      name, constraint = dependency['name'], dependency['version_requirement']
      name = name.tr('/', '-')

      dependency = {
        :source         => release,
        :target         => name,
        :constraint     => constraint,
        :range          => safe_range(constraint)
      }

      dependencies << dependency
    end

    release
  end

  def get_remote_constraints(release)
    # hash of module releases available for installation either from local
    # tarballs or from Forge
    @available = Hash.new { |h,k| h[k] = [] }

    errors = []
    query = if release
      # remember the local tarball release
      @available[@module_name] << release

      # compile the forge query from the release dependencies
      release[:dependencies].map do |dependency|
        begin
          [
            # full module name in the form author/module_name
            Puppet::ModuleTool.username_and_modname_from(dependency[:target]).join('/'),
            # version constraint on the module
            dependency[:constraint] ? dependency[:constraint] : '>= 0.0.0'
          ]
        rescue ArgumentError => e
          errors << e.message
          next
        end
      end
    else
      # define a forge query from the command line arguments
      [
        begin
          [
            # full module name in the form author/module_name
            Puppet::ModuleTool.username_and_modname_from(@module_name).join('/'),
            # version constraint on the module
            @version || '>= 0.0.0'
          ]
        rescue ArgumentError => e
          errors << e.message
        end
      ]
    end

    raise Puppet::Forge::Errors::VerboseForgeError.new(
      "Could not construct a valid query for #{@forge.uri}",
      "Encountered the following problems:\n" << errors.map { |e| '  ' << e }.join("\n")
    ) unless errors.empty?

    Puppet.notice "Querying #{@forge.uri} ..."
    info = @forge.multiple_remote_dependency_info(query)

    # create a release structure for each release in the forge response
    info.each_pair do |module_name, release_infos|
      module_name = module_name.tr('/', '-')

      release_infos.each do |release_info|
        version = release_info['version']

        release = {
          :module_name      => module_name,
          :version          => version,
          :semver           => safe_semver(version),
          :url              => release_info['file'],
          :previous         => @installed[module_name].first,
          :dependencies     => []
        }

        dependencies = release[:dependencies]
        (release_info['dependencies'] || []).each do |name, constraint|
          name = name.tr('/', '-')

          dependency = {
            :source         => release,
            :target         => name,
            :constraint     => constraint,
            :range          => safe_range(constraint)
          }

          dependencies << dependency
        end

        # remember the release
        @available[module_name] << release
      end

      # sort the available releases of each module by version descending
      @available[module_name].sort! { |a, b| b[:semver] <=> a[:semver] }
    end
  end

  # Given an array of lengths of arrays it yields a sequence of offsets into those arrays
  # in which all the offsets increase uniformly.
  # For example given the following array:
  #   [4, 2, 3]
  # (in which each member indicates a length of some other array)
  # it yields the following sequence of offsets into those arrays:
  #   [0, 0, 0]
  #   [0, 0, 1]
  #   [0, 1, 0]
  #   [1, 0, 0]
  #   [0, 1, 1]
  #   [1, 0, 1]
  #   [1, 1, 0]
  #   [1, 1, 1]
  #   [0, 0, 2]
  #   [2, 0, 0]
  #   [0, 1, 2]
  #   [2, 1, 0]
  #   [1, 0, 2]
  #   [2, 0, 1]
  #   [1, 1, 2]
  #   [2, 1, 1]
  #   [2, 0, 2]
  #   [2, 1, 2]
  #   [3, 0, 0]
  #   [3, 0, 1]
  #   [3, 1, 0]
  #   [3, 1, 1]
  #   [3, 0, 2]
  #   [3, 1, 2]
  def uniformly_increasing_sequence(arr, base = arr.max)
    yield Array.new(arr.length, 0)

    1.upto(base-1) do |base|
      thisindexmap = []
      subindexmap = []
      subarr = []

      subbase = 1
      arr.each_index do |index|
        indexbase = arr[index]
        if indexbase <= base
          subbase = indexbase if indexbase > subbase
          subarr << indexbase
          subindexmap
        else
          thisindexmap
        end << index
      end

      (thisindexmap.length-1).downto(0) do |length|
        uniformly_increasing_sequence(Array.new(length, base) + subarr, length > 0 ? base : subbase) do |subsequence|
          thisindexmap.combination(length) do |indexmap|
            indexmap += subindexmap
            sequence = Array.new(arr.length, base)
            subsequence.each_index do |index|
              sequence[indexmap[index]] = subsequence[index]
            end
            yield sequence
          end
        end
      end
    end
  end

  # Given an array of lengths of arrays it yields a sequence of offsets into those arrays
  # in which all the offsets except those present in the nonuniform parameter increase
  # uniformly.
  def mostly_uniformly_increasing_sequence(arr, nonuniform = [])
    indexmap = (0...arr.length).to_a
    nonuniform.reject! do |index|
      next true unless (index >= 0 && index < arr.length)
      if arr[index] > 1
        indexmap[index] = nil
        false
      else
        true
      end
    end

    unless nonuniform.empty?
      subarr = []
      indexmap = indexmap.select { |index|
        next false unless index
        subarr << arr[index]
        true
      }

      uniformly_increasing_sequence(subarr) do |subsequence|
        sequence = Array.new(arr.length, 0)
        subsequence.each_index do |index|
          sequence[indexmap[index]] = subsequence[index]
        end
        yield sequence
      end

      uniformly_increasing_sequence(arr) do |sequence|
        yield sequence if nonuniform.any? { |index| sequence[index] > 0 }
      end
    else
      uniformly_increasing_sequence(arr) do |sequence|
        yield sequence
      end
    end
  end

  def has_local_changes?(release)
    has_local_changes = release[:has_local_changes]
    return has_local_changes unless has_local_changes.nil?
    mod = release[:module]
    release[:has_local_changes] = mod.has_metadata? && mod.has_local_changes?
  end

  def resolve_constraints(dependencies, selected = {})
    candidates = []
    preferred = []
    dependencies.each { |module_name, constraints|
      range = constraints.map { |constraint| constraint[:range] }.inject(&:&)

      if selected.include?(module_name)
        # if already selected then the newly discovered constraints must not
        # confilct with the already selected module release
        if range === selected[module_name][:semver]
          # the previously selected module release matches the newly discoverd constraint
          # in which case we don't need to deal with it any more
          next
        else
          # the previously selected module release does not match the newly discovered
          # constraint which means we need to backtrack
          local_constraints = @conditions[module_name].select { |constraint|
            # ignore constraints from modules which are being upgraded
            !selected.include?(constraint[:source][:module_name])
          }
          raise NoVersionsSatisfyError,
            :requested_name    => @module_name,
            :requested_version => @version || :best,
            :installed_version => @installed[@module_name].empty? ? nil : @installed[@module_name].first[:version],
            :dependency_name   => module_name,
            :conditions        => constraints + local_constraints,
            :action            => @action
        end
      end

      # consider only module releases satisfying the dependency constraint
      # TODO select only releases which can potentially result in different resolutions
      releases = @available[module_name].select { |release|
        range === release[:semver]
      }

      if module_name != @module_name && previous = @installed[module_name].first
        # some release of the module is already installed ...
        if range === previous[:semver]
          # ... and the installed release statisfies the constraints
          releases.unshift(previous)
          if !@force && (@action == :install || has_local_changes?(previous))
            # if we are installing, or if the already installed release is modified,
            # then treat the already installed release as preferred
            preferred << candidates.length
          else
            # else treat it as any other release, i.e. insert it into the sorted array
            # of releases such that the array stays sorted
            1.upto(releases.length-1) do |index|
              release = releases[index]
              break if previous[:semver] >= release[:semver]
              releases[index-1] = release
              releases[index] = previous
            end
          end
        end
      end

      # there is no module release satisfying the constriant so we need to backtrack
      if releases.empty?
        local_constraints = @conditions[module_name].select { |constraint|
          # ignore constraints from modules which are being upgraded
          !selected.include?(constraint[:source][:module_name])
        }
        raise NoVersionsSatisfyError,
          :requested_name    => @module_name,
          :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
          :installed_version => @installed[@module_name].empty? ? nil : @installed[@module_name].first[:version],
          :dependency_name   => module_name,
          :conditions        => constraints + local_constraints,
          :action            => @action
      end

      candidates << releases
    }

    # we are done if there are no dependencies left to be resolved
    return [] if candidates.empty?

    resolution_exception = nil
    # try all possible combinations of candidates in unifromly increasing sequence
    mostly_uniformly_increasing_sequence(candidates.map(&:length), preferred) do |offsets|
      # the current set of candidates (possible resolutions) to try
      candidate_set = []

      # dependencies to resolve in the next recursion
      # (constraints imposed by the candidates in the candidate set)
      subdependencies = Hash.new { |h,k| h[k] = [] }

      # map of parents used to link resolutions of dependencies to the candidates
      # in the current candidate set to build the install/upgrade tree which
      # is printed by the install/upgrade command
      parentmap = {}

      # select the next set of candidates/resolutions
      # and gather their dependencies
      candidates.each_index do |index|
        release = candidates[index][offsets[index]]

        release[:dependencies].each do |dependency|
          name = dependency[:target]
          parentmap[name] = index unless parentmap.include?(name)
          subdependencies[name] << dependency
        end

        selected[release[:module_name]] = release
        candidate_set << release
      end

      begin
        subresolutions = @ignore_dependencies ? [] : resolve_constraints(subdependencies, selected)

        resolutions = candidate_set.map do |release|
	  # perfrom post-resolution checks on modules installed from Forge (or a tarball)
	  # (skip the checks if --force was specified)
	  unless @force || release[:module] # skip already installed modules
            module_name = release[:module_name]

            # verify that constraints imposed by already installed modules
            # are not violated
            constraints = @conditions[module_name].select { |constraint|
              # ignore constraints from modules which are being upgraded
              !selected.include?(constraint[:source][:module_name])
            }
            range = constraints.map { |constraint| constraint[:range] }.inject(&:&)

            unless constraints.empty? || range === release[:semver]
              raise NoVersionsSatisfyError,
                :requested_name    => @module_name,
                :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
                :installed_version => @installed[@module_name].empty? ? nil : @installed[@module_name].first[:version],
                :dependency_name   => module_name,
                :conditions        => constraints,
                :action            => @action
            end

            # more checks in case we are to upgrade a module
            if module_name != @module_name && previous = release[:previous]
              # refuse to downgrade
              if previous[:semver] > release[:semver]
                raise NewerInstalledError,
                  :action            => @action,
                  :module_name       => module_name,
                  :requested_version => release[:version] || :best,
                  :installed_version => previous[:version]
              end
              # refuse to replace a modified module release
              if has_local_changes?(previous)
                raise LocalChangesError,
                  :action            => @action,
                  :module_name       => module_name,
                  :requested_version => release[:version] || :best,
                  :installed_version => previous[:version]
              end
            end
          end

          # the rosultion consists of the release satisfying the constriants
          # and the list of resolutions satisfying its dependencies (to be
          # filled in just below)
          resolution = {
            :release => release,
            :dependencies => []
          }

          resolution
        end

        # link the subresolutions with the resolutions to from the install/upgrade tree
        subresolutions.each do |subresolution|
          resolutions[parentmap[subresolution[:release][:module_name]]][:dependencies] << subresolution
        end

        # discard those rosolutions which appoint allready installed module releases
        # and which have no dependencies, as we don't want to include such
        # releases in the install/upgrade tree which is printed
        # by the install/upgrade command
        # sort the dependencies of the remaining resolutions so as to display
        # consistent results
        resolutions.reject! do |resolution|
          unless resolution[:release][:module] && resolution[:dependencies].empty?
            resolution[:dependencies] = resolution[:dependencies].sort_by { |dependency|
              dependency[:release][:module_name]
            }
            false
          else
            true
          end
        end

        return resolutions
      rescue ModuleToolError => e
        resolution_exception = e
        # fall through to try the next candidate set
      end

      # the currently selected candidate set is could not be resolved
      # we need to unselected the respective releaes and try the next set
      candidate_set.each do |release|
        selected.delete(release[:module_name])
      end
    end

    # add any constraints there may be for the module that is the subject
    # of the NoVersionsSatisfyError so that they are diplayed if/when
    # the error is eventually reported
    if resolution_exception.is_a? NoVersionsSatisfyError
       dependencies = dependencies[resolution_exception.dependency_name]
       resolution_exception.add_conditions(dependencies) unless (!dependencies || dependencies.empty?)
    end

    # no more combinations to try, re-raise the most recent exception
    raise resolution_exception
  end

  #
  # Resolve installation conflicts by checking if the requested module
  # or one of it's dependencies conflicts with an installed module.
  #
  # Conflicts occur under the following conditions:
  #
  # When installing 'puppetlabs-foo' and an existing directory in the
  # target install path contains a 'foo' directory and we cannot determine
  # the "full name" of the installed module.
  #
  # When installing 'puppetlabs-foo' and 'pete-foo' is already installed.
  # This is considered a conflict because 'puppetlabs-foo' and 'pete-foo'
  # install into the same directory 'foo'.
  #
  def resolve_install_conflicts(graph, is_dependency = false)
    graph.each do |resolution|
      release = resolution[:release]
      next if release[:module] # skip already installed module releases

      @environment.modules_by_path[options[:target_dir]].each do |mod|
        if mod.has_metadata?
          metadata = {
            :name    => mod.forge_name.tr('/', '-'),
            :version => mod.version
          }
          next if release[:module_name] == metadata[:name]
        else
          metadata = nil
        end

        if release[:module_name] =~ /-#{mod.name}$/
          dependency = is_dependency ? {
            :name    => release[:module_name],
            :version => release[:version]
          } : nil

          raise InstallConflictError,
            :requested_module  => @module_name,
            :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
            :dependency        => dependency,
            :directory         => mod.path,
            :metadata          => metadata
        end

        resolve_install_conflicts(resolution[:dependencies], true)
      end
    end
  end

  #
  # Resolve the constraints of the module specified for installation/upgrade
  # producing a resolution graph. Then pass the graph to +download_tarballs+
  # and return its return value.
  #
  def get_release_packages(metadata)
    if (tarball_release = get_release(metadata, @name)) &&
      (@ignore_dependencies || dependencies_statisfied_locally?(tarball_release[:dependencies]))
    then
      # it turns out to be possible to install/upgrade without querying
      # Forge, so here we build a degenerate resolution graph reflecting
      # that

      # but first we check if it is safe to upgrade the module (if it is to be upgraded at all)
      if !@force && (previous = tarball_release[:previous]) && has_local_changes?(previous)
         module_name = tarball_release[:module_name]
         raise LocalChangesError,
           :action            => @action,
           :module_name       => module_name,
           :requested_version => tarball_release[:version] || (@conditions[module_name].empty? ? :latest : :best),
           :installed_version => previous[:version]
      end

      @graph = [{
        :release           => tarball_release,
        :dependencies      => []
      }]
    else
      # query the froge for the module itself if not installing from a local tarball
      # or for its dependencies otherwise
      get_remote_constraints(tarball_release)

      @graph = resolve_constraints({
        @module_name => [{
          #:source          => nil,
          :target           => @module_name,
          :constraint       => @version,
          :range            => safe_range(@version)
        }]
      })
    end

    resolve_install_conflicts(@graph) unless @force

    # This clean call means we never "cache" the module we're installing, but this
    # is desired since module authors can easily rerelease modules different content but the same
    # version number, meaning someone with the old content cached will be very confused as to why
    # they can't get new content.
    # Long term we should just get rid of this caching behavior and cleanup downloaded modules after they install
    # but for now this is a quick fix to disable caching
    Puppet::Forge::Cache.clean
    download_tarballs(@graph, @options[:target_dir])
  end

  #
  # For the given resoluton graph, return an array of hashes, each hash containing
  # just a single mapping where the key is a modulepath dir and the value is a module
  # tarball to install into the modulepath.
  #
  def download_tarballs(graph, default_path, result = [])
    graph.each do |resolution|
      release = resolution[:release]

      # add these fields for backward compatibility
      resolution[:module] = release[:module_name]
      resolution[:version] = {
        :vstring => release[:version],
        :version => release[:semver],
      }

      unless release[:module] # skip already installed module releases
        begin
          url = release[:url]
          if url.start_with?('file:')
            cache_path = Pathname(url[5..-1])
          else
            cache_path = @forge.retrieve(url)
          end
        rescue OpenURI::HTTPError => e
          raise RuntimeError, "Could not download module: #{e.message}"
        end

        previous = release[:previous]
        resolution[:path] = previous ? previous[:module].modulepath : default_path
        result << { resolution[:path] => cache_path }
      end

      download_tarballs(resolution[:dependencies], default_path, result)
    end

    result
  end

  #
  # Check if a file is a vaild module package.
  #
  def read_module_package_metadata(name)
    return nil unless name.end_with?('.tar.gz')
    Puppet.notice "Reading metadata from '#{name}' ..."
    raise MissingPackageError, :action => @action, :requested_package => File.expand_path(name) unless File.file?(name)
    begin
      Zlib::GzipReader.open(name) do |gzip|
        Puppet::Util::Archive::Tar::Minitar::Reader.open(gzip) do |tar|
          tar.each do |entry|
            name_components = entry.full_name.split('/', 3)
            next unless (name_components.length == 2 && name_components.last == 'metadata.json')
            return PSON.parse(entry.read)
          end
        end
      end
    rescue => e
      raise InvalidPackageError, :action => @action, :requested_package => File.expand_path(name), :detail => 'Error during extraction of module metadata: ' + e.message
    end
    raise InvalidPackageError, :action => @action, :requested_package => File.expand_path(name), :detail => 'The package is missing metadata file: metadata.json'
  end

  #
  # Check if the given dependencies are statisfied by already installed
  # module releases.
  #
  def dependencies_statisfied_locally?(dependencies, checked = {})
    dependencies.each do |dependency|
      if (installed = @installed[dependency[:target]].first) && dependency[:range] === installed[:semver]
        next if checked.include?(installed)
        checked[installed] = true
        next if dependencies_statisfied_locally?(installed[:dependencies], checked)
      end
      return false
    end

    true
  end
end
