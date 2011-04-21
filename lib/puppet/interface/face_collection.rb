# -*- coding: utf-8 -*-
require 'puppet/interface'

module Puppet::Interface::FaceCollection
  SEMVER_VERSION = /^(\d+)\.(\d+)\.(\d+)([A-Za-z][0-9A-Za-z-]*|)$/

  @faces = Hash.new { |hash, key| hash[key] = {} }

  def self.faces
    unless @loaded
      @loaded = true
      $LOAD_PATH.each do |dir|
        next unless FileTest.directory?(dir)
        Dir.chdir(dir) do
          Dir.glob("puppet/face/*.rb").collect { |f| f.sub(/\.rb/, '') }.each do |file|
            iname = file.sub(/\.rb/, '')
            begin
              require iname
            rescue Exception => detail
              puts detail.backtrace if Puppet[:trace]
              raise "Could not load #{iname} from #{dir}/#{file}: #{detail}"
            end
          end
        end
      end
    end
    return @faces.keys.select {|name| @faces[name].length > 0 }
  end

  def self.validate_version(version)
    !!(SEMVER_VERSION =~ version.to_s)
  end

  def self.semver_to_array(v)
    parts = SEMVER_VERSION.match(v).to_a[1..4]
    parts[0..2] = parts[0..2].map { |e| e.to_i }
    parts
  end

  def self.cmp_semver(a, b)
    a, b = [a, b].map do |x| semver_to_array(x) end

    cmp = a[0..2] <=> b[0..2]
    if cmp == 0
      cmp = a[3] <=> b[3]
      cmp = +1 if a[3].empty? && !b[3].empty?
      cmp = -1 if b[3].empty? && !a[3].empty?
    end
    cmp
  end

  def self.prefix_match?(desired, target)
    # Can't meaningfully do a prefix match with current on either side.
    return false if desired == :current
    return false if target  == :current

    # REVISIT: Should probably fail if the matcher is not valid.
    prefix = desired.split('.').map {|x| x =~ /^\d+$/ and x.to_i }
    have   = semver_to_array(target)

    while want = prefix.shift do
      return false unless want == have.shift
    end
    return true
  end

  def self.[](name, version)
    name = underscorize(name)
    get_face(name, version) or load_face(name, version)
  end

  # get face from memory, without loading.
  def self.get_face(name, desired_version)
    return nil unless @faces.has_key? name

    return @faces[name][:current] if desired_version == :current

    found = @faces[name].keys.select {|v| prefix_match?(desired_version, v) }.sort.last
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
        latest_ver = @faces[name].keys.sort {|a, b| cmp_semver(a, b) }.last
        @faces[name][:current] = @faces[name][latest_ver]
      end
    rescue LoadError => e
      raise unless e.message =~ %r{-- puppet/face/#{name}$}
      # ...guess we didn't find the file; return a much better problem.
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
