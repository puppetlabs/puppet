module Puppet::Interface::FaceCollection
  @faces = Hash.new { |hash, key| hash[key] = {} }

  @loader = Puppet::Util::Autoload.new(:application, 'puppet/face')

  def self.faces
    unless @loaded
      @loaded = true
      names = @loader.files_to_load.map {|fn| ::File.basename(fn, '.rb')}.uniq
      names.each {|name| self[name, :current]}
    end
    @faces.keys.select {|name| @faces[name].length > 0 }
  end

  def self.[](name, version)
    name = underscorize(name)
    get_face(name, version) or load_face(name, version)
  end

  def self.get_action_for_face(name, action_name, version)
    name = underscorize(name)

    # If the version they request specifically doesn't exist, don't search
    # elsewhere.  Usually this will start from :current and all...
    return nil unless face = self[name, version]
    unless action = face.get_action(action_name)
      # ...we need to search for it bound to an o{lder,ther} version.  Since
      # we load all actions when the face is first references, this will be in
      # memory in the known set of versions of the face.
      (@faces[name].keys - [ :current ]).sort.reverse_each do |vers|
        break if action = @faces[name][vers].get_action(action_name)
      end
    end

    return action
  end

  # get face from memory, without loading.
  def self.get_face(name, pattern)
    return nil unless @faces.has_key? name
    return @faces[name][:current] if pattern == :current

    versions = @faces[name].keys - [ :current ]
    range = pattern.is_a?(SemanticPuppet::Version) ? SemanticPuppet::VersionRange.new(pattern, pattern) : SemanticPuppet::VersionRange.parse(pattern)
    found = find_matching(range, versions)
    return @faces[name][found]
  end

  def self.find_matching(range, versions)
    versions.select { |v| range === v }.sort.last
  end

  # try to load the face, and return it.
  def self.load_face(name, version)
    # We always load the current version file; the common case is that we have
    # the expected version and any compatibility versions in the same file,
    # the default.  Which means that this is almost always the case.
    #
    # We use require to avoid executing the code multiple times, like any
    # other Ruby library that we might want to use.  --daniel 2011-04-06
    if safely_require name then
      # If we wanted :current, we need to index to find that; direct version
      # requests just work as they go. --daniel 2011-04-06
      if version == :current then
        # We need to find current out of this.  This is the largest version
        # number that doesn't have a dedicated on-disk file present; those
        # represent "experimental" versions of faces, which we don't fully
        # support yet.
        #
        # We walk the versions from highest to lowest and take the first version
        # that is not defined in an explicitly versioned file on disk as the
        # current version.
        #
        # This constrains us to only ship experimental versions with *one*
        # version in the file, not multiple, but given you can't reliably load
        # them except by side-effect when you ignore that rule this seems safe
        # enough...
        #
        # Given those constraints, and that we are not going to ship a versioned
        # interface that is not :current in this release, we are going to leave
        # these thoughts in place, and just punt on the actual versioning.
        #
        # When we upgrade the core to support multiple versions we can solve the
        # problems then; as lazy as possible.
        #
        # We do support multiple versions in the same file, though, so we sort
        # versions here and return the last item in that set.
        #
        # --daniel 2011-04-06
        latest_ver = @faces[name].keys.sort.last
        @faces[name][:current] = @faces[name][latest_ver]
      end
    end

    unless version == :current or get_face(name, version)
      # Try an obsolete version of the face, if needed, to see if that helps?
      safely_require name, version
    end

    return get_face(name, version)
  end

  def self.safely_require(name, version = nil)
    path = @loader.expand(version ? ::File.join(version.to_s, name.to_s) : name)
    require path
    true

  rescue LoadError => e
    raise unless e.message =~ %r{-- #{path}$}
    # ...guess we didn't find the file; return a much better problem.
    nil
  rescue SyntaxError => e
    raise unless e.message =~ %r{#{path}\.rb:\d+: }
    Puppet.err _("Failed to load face %{name}:\n%{detail}") % { name: name, detail: e }
    # ...but we just carry on after complaining.
    nil
  end

  def self.register(face)
    @faces[underscorize(face.name)][face.version] = face
  end

  def self.underscorize(name)
    unless name.to_s =~ /^[-_a-z][-_a-z0-9]*$/i then
      #TRANSLATORS 'face' refers to a programming API in Puppet
      raise ArgumentError, _("%{name} (%{class_name}) is not a valid face name") %
          { name: name.inspect, class_name: name.class }
    end

    name.to_s.downcase.split(/[-_]/).join('_').to_sym
  end
end
