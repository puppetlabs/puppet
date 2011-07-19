require 'puppet/interface'

module Puppet::Interface::FaceCollection
  @faces = Hash.new { |hash, key| hash[key] = {} }

  def self.faces
    unless @loaded
      @loaded = true
      $LOAD_PATH.each do |dir|
        Dir.glob("#{dir}/puppet/face/*.rb").
          collect {|f| File.basename(f, '.rb') }.
          each {|name| self[name, :current] }
      end
    end
    @faces.keys.select {|name| @faces[name].length > 0 }
  end

  def self.[](name, version)
    name = underscorize(name)
    get_face(name, version) or load_face(name, version)
  end

  # get face from memory, without loading.
  def self.get_face(name, pattern)
    return nil unless @faces.has_key? name
    return @faces[name][:current] if pattern == :current

    versions = @faces[name].keys - [ :current ]
    found    = SemVer.find_matching(pattern, versions)
    return @faces[name][found]
  end

  # try to load the face, and return it.
  def self.load_face(name, version)
    # We always load the current version file; the common case is that we have
    # the expected version and any compatibility versions in the same file,
    # the default.  Which means that this is almost always the case.
    #
    # We use require to avoid executing the code multiple times, like any
    # other Ruby library that we might want to use.  --daniel 2011-04-06
    begin
      require "puppet/face/#{name}"

      # If we wanted :current, we need to index to find that; direct version
      # requests just work™ as they go. --daniel 2011-04-06
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
    rescue LoadError => e
      raise unless e.message =~ %r{-- puppet/face/#{name}$}
      # ...guess we didn't find the file; return a much better problem.
    rescue SyntaxError => e
      raise unless e.message =~ %r{puppet/face/#{name}\.rb:\d+: }
      Puppet.err "Failed to load face #{name}:\n#{e}"
      # ...but we just carry on after complaining.
    end

    return get_face(name, version)
  end

  def self.register(face)
    @faces[underscorize(face.name)][face.version] = face
  end

  def self.underscorize(name)
    unless name.to_s =~ /^[-_a-z]+$/i then
      raise ArgumentError, "#{name.inspect} (#{name.class}) is not a valid face name"
    end

    name.to_s.downcase.split(/[-_]/).join('_').to_sym
  end
end
