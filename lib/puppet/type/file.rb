require 'digest/md5'
require 'cgi'
require 'etc'
require 'uri'
require 'fileutils'
require 'enumerator'
require 'pathname'
require 'puppet/network/handler'
require 'puppet/util/diff'
require 'puppet/util/checksums'
require 'puppet/util/backups'

Puppet::Type.newtype(:file) do
  include Puppet::Util::MethodHelper
  include Puppet::Util::Checksums
  include Puppet::Util::Backups
  @doc = "Manages local files, including setting ownership and
    permissions, creation of both files and directories, and
    retrieving entire files from remote servers.  As Puppet matures, it
    expected that the `file` resource will be used less and less to
    manage content, and instead native resources will be used to do so.

    If you find that you are often copying files in from a central
    location, rather than using native resources, please contact
    Puppet Labs and we can hopefully work with you to develop a
    native resource to support what you are doing.

    **Autorequires:** If Puppet is managing the user or group that owns a
    file, the file resource will autorequire them. If Puppet is managing any
    parent directories of a file, the file resource will autorequire them."

  def self.title_patterns
    [ [ /^(.*?)\/*\Z/m, [ [ :path, lambda{|x| x} ] ] ] ]
  end

  newparam(:path) do
    desc "The path to the file to manage.  Must be fully qualified."
    isnamevar

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        fail Puppet::Error, "File paths must be fully qualified, not '#{value}'"
      end
    end

    # convert the current path in an index into the collection and the last
    # path name. The aim is to use less storage for all common paths in a hierarchy
    munge do |value|
      # We know the value is absolute, so expanding it will just standardize it.
      path, name = ::File.split(::File.expand_path(value))

      { :index => Puppet::FileCollection.collection.index(path), :name => name }
    end

    # and the reverse
    unmunge do |value|
      basedir = Puppet::FileCollection.collection.path(value[:index])

      ::File.join( basedir, value[:name] )
    end
  end

  newparam(:backup) do
    desc "Whether files should be backed up before
      being replaced.  The preferred method of backing files up is via
      a `filebucket`, which stores files by their MD5 sums and allows
      easy retrieval without littering directories with backups.  You
      can specify a local filebucket or a network-accessible
      server-based filebucket by setting `backup => bucket-name`.
      Alternatively, if you specify any value that begins with a `.`
      (e.g., `.puppet-bak`), then Puppet will use copy the file in
      the same directory with that value as the extension of the
      backup. Setting `backup => false` disables all backups of the
      file in question.

      Puppet automatically creates a local filebucket named `puppet` and
      defaults to backing up there.  To use a server-based filebucket,
      you must specify one in your configuration.

            filebucket { main:
              server => puppet,
              path   => false,
              # The path => false line works around a known issue with the filebucket type.
            }

      The `puppet master` daemon creates a filebucket by default,
      so you can usually back up to your main server with this
      configuration.  Once you've described the bucket in your
      configuration, you can use it in any file's backup attribute:

            file { \"/my/file\":
              source => \"/path/in/nfs/or/something\",
              backup => main
            }

      This will back the file up to the central server.

      At this point, the benefits of using a central filebucket are that you
      do not have backup files lying around on each of your machines, a given
      version of a file is only backed up once, you can restore any given file
      manually (no matter how old), and you can use Puppet Dashboard to view
      file contents.  Eventually, transactional support will be able to
      automatically restore filebucketed files.
      "

    defaultto "puppet"

    munge do |value|
      # I don't really know how this is happening.
      value = value.shift if value.is_a?(Array)

      case value
      when false, "false", :false
        false
      when true, "true", ".puppet-bak", :true
        ".puppet-bak"
      when String
        value
      else
        self.fail "Invalid backup type #{value.inspect}"
      end
    end
  end

  newparam(:recurse) do
    desc "Whether and how deeply to do recursive
      management. Options are:

      * `inf,true` --- Regular style recursion on both remote and local
        directory structure.
      * `remote` --- Descends recursively into the remote directory
        but not the local directory. Allows copying of
        a few files into a directory containing many
        unmanaged files without scanning all the local files.
      * `false` --- Default of no recursion.
      * `[0-9]+` --- Same as true, but limit recursion. Warning: this syntax
        has been deprecated in favor of the `recurselimit` attribute.
    "

    newvalues(:true, :false, :inf, :remote, /^[0-9]+$/)

    # Replace the validation so that we allow numbers in
    # addition to string representations of them.
    validate { |arg| }
    munge do |value|
      newval = super(value)
      case newval
      when :true, :inf; true
      when :false; false
      when :remote; :remote
      when Integer, Fixnum, Bignum
        self.warning "Setting recursion depth with the recurse parameter is now deprecated, please use recurselimit"

        # recurse == 0 means no recursion
        return false if value == 0

        resource[:recurselimit] = value
        true
      when /^\d+$/
        self.warning "Setting recursion depth with the recurse parameter is now deprecated, please use recurselimit"
        value = Integer(value)

        # recurse == 0 means no recursion
        return false if value == 0

        resource[:recurselimit] = value
        true
      else
        self.fail "Invalid recurse value #{value.inspect}"
      end
    end
  end

  newparam(:recurselimit) do
    desc "How deeply to do recursive management."

    newvalues(/^[0-9]+$/)

    munge do |value|
      newval = super(value)
      case newval
      when Integer, Fixnum, Bignum; value
      when /^\d+$/; Integer(value)
      else
        self.fail "Invalid recurselimit value #{value.inspect}"
      end
    end
  end

  newparam(:replace, :boolean => true) do
    desc "Whether or not to replace a file that is
      sourced but exists.  This is useful for using file sources
      purely for initialization."
    newvalues(:true, :false)
    aliasvalue(:yes, :true)
    aliasvalue(:no, :false)
    defaultto :true
  end

  newparam(:force, :boolean => true) do
    desc "Force the file operation.  Currently only used when replacing
      directories with links."
    newvalues(:true, :false)
    defaultto false
  end

  newparam(:ignore) do
    desc "A parameter which omits action on files matching
      specified patterns during recursion.  Uses Ruby's builtin globbing
      engine, so shell metacharacters are fully supported, e.g. `[a-z]*`.
      Matches that would descend into the directory structure are ignored,
      e.g., `*/*`."

    validate do |value|
      unless value.is_a?(Array) or value.is_a?(String) or value == false
        self.devfail "Ignore must be a string or an Array"
      end
    end
  end

  newparam(:links) do
    desc "How to handle links during file actions.  During file copying,
      `follow` will copy the target file instead of the link, `manage`
      will copy the link itself, and `ignore` will just pass it by.
      When not copying, `manage` and `ignore` behave equivalently
      (because you cannot really ignore links entirely during local
      recursion), and `follow` will manage the file to which the link points."

    newvalues(:follow, :manage)

    defaultto :manage
  end

  newparam(:purge, :boolean => true) do
    desc "Whether unmanaged files should be purged.  If you have a filebucket
      configured the purged files will be uploaded, but if you do not,
      this will destroy data.  Only use this option for generated
      files unless you really know what you are doing.  This option only
      makes sense when recursively managing directories.

      Note that when using `purge` with `source`, Puppet will purge any files
      that are not on the remote system."

    defaultto :false

    newvalues(:true, :false)
  end

  newparam(:sourceselect) do
    desc "Whether to copy all valid sources, or just the first one.  This parameter
      is only used in recursive copies; by default, the first valid source is the
      only one used as a recursive source, but if this parameter is set to `all`,
      then all valid sources will have all of their contents copied to the local host,
      and for sources that have the same file, the source earlier in the list will
      be used."

    defaultto :first

    newvalues(:first, :all)
  end

  # Autorequire the nearest ancestor directory found in the catalog.
  autorequire(:file) do
    path = Pathname.new(self[:path])
    if !path.root?
      # Start at our parent, to avoid autorequiring ourself
      parents = path.parent.enum_for(:ascend)
      found = parents.find { |p| catalog.resource(:file, p.to_s) }
      found and found.to_s
    end
  end

  # Autorequire the owner and group of the file.
  {:user => :owner, :group => :group}.each do |type, property|
    autorequire(type) do
      if @parameters.include?(property)
        # The user/group property automatically converts to IDs
        next unless should = @parameters[property].shouldorig
        val = should[0]
        if val.is_a?(Integer) or val =~ /^\d+$/
          nil
        else
          val
        end
      end
    end
  end

  CREATORS = [:content, :source, :target]
  SOURCE_ONLY_CHECKSUMS = [:none, :ctime, :mtime]

  validate do
    creator_count = 0
    CREATORS.each do |param|
      creator_count += 1 if self.should(param)
    end
    creator_count += 1 if @parameters.include?(:source)
    self.fail "You cannot specify more than one of #{CREATORS.collect { |p| p.to_s}.join(", ")}" if creator_count > 1

    self.fail "You cannot specify a remote recursion without a source" if !self[:source] and self[:recurse] == :remote

    self.fail "You cannot specify source when using checksum 'none'" if self[:checksum] == :none && !self[:source].nil?

    SOURCE_ONLY_CHECKSUMS.each do |checksum_type|
      self.fail "You cannot specify content when using checksum '#{checksum_type}'" if self[:checksum] == checksum_type && !self[:content].nil?
    end

    self.warning "Possible error: recurselimit is set but not recurse, no recursion will happen" if !self[:recurse] and self[:recurselimit]

    provider.validate if provider.respond_to?(:validate)
  end

  def self.[](path)
    return nil unless path
    super(path.gsub(/\/+/, '/').sub(/\/$/, ''))
  end

  def self.instances
    return []
  end

  # Determine the user to write files as.
  def asuser
    if self.should(:owner) and ! self.should(:owner).is_a?(Symbol)
      writeable = Puppet::Util::SUIDManager.asuser(self.should(:owner)) {
        FileTest.writable?(::File.dirname(self[:path]))
      }

      # If the parent directory is writeable, then we execute
      # as the user in question.  Otherwise we'll rely on
      # the 'owner' property to do things.
      asuser = self.should(:owner) if writeable
    end

    asuser
  end

  def bucket
    return @bucket if @bucket

    backup = self[:backup]
    return nil unless backup
    return nil if backup =~ /^\./

    unless catalog or backup == "puppet"
      fail "Can not find filebucket for backups without a catalog"
    end

    unless catalog and filebucket = catalog.resource(:filebucket, backup) or backup == "puppet"
      fail "Could not find filebucket #{backup} specified in backup"
    end

    return default_bucket unless filebucket

    @bucket = filebucket.bucket

    @bucket
  end

  def default_bucket
    Puppet::Type.type(:filebucket).mkdefaultbucket.bucket
  end

  # Does the file currently exist?  Just checks for whether
  # we have a stat
  def exist?
    stat ? true : false
  end

  # We have to do some extra finishing, to retrieve our bucket if
  # there is one.
  def finish
    # Look up our bucket, if there is one
    bucket
    super
  end

  # Create any children via recursion or whatever.
  def eval_generate
    return [] unless self.recurse?

    recurse
    #recurse.reject do |resource|
    #    catalog.resource(:file, resource[:path])
    #end.each do |child|
    #    catalog.add_resource child
    #    catalog.relationship_graph.add_edge self, child
    #end
  end

  def ancestors
    ancestors = Pathname.new(self[:path]).enum_for(:ascend).map(&:to_s)
    ancestors.delete(self[:path])
    ancestors
  end

  def flush
    # We want to make sure we retrieve metadata anew on each transaction.
    @parameters.each do |name, param|
      param.flush if param.respond_to?(:flush)
    end
    @stat = :needs_stat
  end

  def initialize(hash)
    # Used for caching clients
    @clients = {}

    super

    # If they've specified a source, we get our 'should' values
    # from it.
    unless self[:ensure]
      if self[:target]
        self[:ensure] = :symlink
      elsif self[:content]
        self[:ensure] = :file
      end
    end

    @stat = :needs_stat
  end

  # Configure discovered resources to be purged.
  def mark_children_for_purging(children)
    children.each do |name, child|
      next if child[:source]
      child[:ensure] = :absent
    end
  end

  # Create a new file or directory object as a child to the current
  # object.
  def newchild(path)
    full_path = ::File.join(self[:path], path)

    # Add some new values to our original arguments -- these are the ones
    # set at initialization.  We specifically want to exclude any param
    # values set by the :source property or any default values.
    # LAK:NOTE This is kind of silly, because the whole point here is that
    # the values set at initialization should live as long as the resource
    # but values set by default or by :source should only live for the transaction
    # or so.  Unfortunately, we don't have a straightforward way to manage
    # the different lifetimes of this data, so we kludge it like this.
    # The right-side hash wins in the merge.
    options = @original_parameters.merge(:path => full_path).reject { |param, value| value.nil? }

    # These should never be passed to our children.
    [:parent, :ensure, :recurse, :recurselimit, :target, :alias, :source].each do |param|
      options.delete(param) if options.include?(param)
    end

    self.class.new(options)
  end

  # Files handle paths specially, because they just lengthen their
  # path names, rather than including the full parent's title each
  # time.
  def pathbuilder
    # We specifically need to call the method here, so it looks
    # up our parent in the catalog graph.
    if parent = parent()
      # We only need to behave specially when our parent is also
      # a file
      if parent.is_a?(self.class)
        # Remove the parent file name
        list = parent.pathbuilder
        list.pop # remove the parent's path info
        return list << self.ref
      else
        return super
      end
    else
      return [self.ref]
    end
  end

  # Should we be purging?
  def purge?
    @parameters.include?(:purge) and (self[:purge] == :true or self[:purge] == "true")
  end

  # Recursively generate a list of file resources, which will
  # be used to copy remote files, manage local files, and/or make links
  # to map to another directory.
  def recurse
    children = (self[:recurse] == :remote) ? {} : recurse_local

    if self[:target]
      recurse_link(children)
    elsif self[:source]
      recurse_remote(children)
    end

    # If we're purging resources, then delete any resource that isn't on the
    # remote system.
    mark_children_for_purging(children) if self.purge?

    result = children.values.sort { |a, b| a[:path] <=> b[:path] }
    remove_less_specific_files(result)
  end

  # This is to fix bug #2296, where two files recurse over the same
  # set of files.  It's a rare case, and when it does happen you're
  # not likely to have many actual conflicts, which is good, because
  # this is a pretty inefficient implementation.
  def remove_less_specific_files(files)
    mypath = self[:path].split(::File::Separator)
    other_paths = catalog.vertices.
      select  { |r| r.is_a?(self.class) and r[:path] != self[:path] }.
      collect { |r| r[:path].split(::File::Separator) }.
      select  { |p| p[0,mypath.length]  == mypath }

    return files if other_paths.empty?

    files.reject { |file|
      path = file[:path].split(::File::Separator)
      other_paths.any? { |p| path[0,p.length] == p }
      }
  end

  # A simple method for determining whether we should be recursing.
  def recurse?
    self[:recurse] == true or self[:recurse] == :remote
  end

  # Recurse the target of the link.
  def recurse_link(children)
    perform_recursion(self[:target]).each do |meta|
      if meta.relative_path == "."
        self[:ensure] = :directory
        next
      end

      children[meta.relative_path] ||= newchild(meta.relative_path)
      if meta.ftype == "directory"
        children[meta.relative_path][:ensure] = :directory
      else
        children[meta.relative_path][:ensure] = :link
        children[meta.relative_path][:target] = meta.full_path
      end
    end
    children
  end

  # Recurse the file itself, returning a Metadata instance for every found file.
  def recurse_local
    result = perform_recursion(self[:path])
    return {} unless result
    result.inject({}) do |hash, meta|
      next hash if meta.relative_path == "."

      hash[meta.relative_path] = newchild(meta.relative_path)
      hash
    end
  end

  # Recurse against our remote file.
  def recurse_remote(children)
    sourceselect = self[:sourceselect]

    total = self[:source].collect do |source|
      next unless result = perform_recursion(source)
      return if top = result.find { |r| r.relative_path == "." } and top.ftype != "directory"
      result.each { |data| data.source = "#{source}/#{data.relative_path}" }
      break result if result and ! result.empty? and sourceselect == :first
      result
    end.flatten

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
      if meta.relative_path == "."
        parameter(:source).metadata = meta
        next
      end
      children[meta.relative_path] ||= newchild(meta.relative_path)
      children[meta.relative_path][:source] = meta.source
      children[meta.relative_path][:checksum] = :md5 if meta.ftype == "file"

      children[meta.relative_path].parameter(:source).metadata = meta
    end

    children
  end

  def perform_recursion(path)
    Puppet::FileServing::Metadata.indirection.search(
      path,
      :links => self[:links],
      :recurse => (self[:recurse] == :remote ? true : self[:recurse]),
      :recurselimit => self[:recurselimit],
      :ignore => self[:ignore],
      :checksum_type => (self[:source] || self[:content]) ? self[:checksum] : :none
    )
  end

  # Remove any existing data.  This is only used when dealing with
  # links or directories.
  def remove_existing(should)
    return unless s = stat

    self.fail "Could not back up; will not replace" unless perform_backup

    unless should.to_s == "link"
      return if s.ftype.to_s == should.to_s
    end

    case s.ftype
    when "directory"
      if self[:force] == :true
        debug "Removing existing directory for replacement with #{should}"
        FileUtils.rmtree(self[:path])
      else
        notice "Not removing directory; use 'force' to override"
        return
      end
    when "link", "file"
      debug "Removing existing #{s.ftype} for replacement with #{should}"
      ::File.unlink(self[:path])
    else
      self.fail "Could not back up files of type #{s.ftype}"
    end
    @stat = :needs_stat
    true
  end

  def retrieve
    if source = parameter(:source)
      source.copy_source_values
    end
    super
  end

  # Set the checksum, from another property.  There are multiple
  # properties that modify the contents of a file, and they need the
  # ability to make sure that the checksum value is in sync.
  def setchecksum(sum = nil)
    if @parameters.include? :checksum
      if sum
        @parameters[:checksum].checksum = sum
      else
        # If they didn't pass in a sum, then tell checksum to
        # figure it out.
        currentvalue = @parameters[:checksum].retrieve
        @parameters[:checksum].checksum = currentvalue
      end
    end
  end

  # Should this thing be a normal file?  This is a relatively complex
  # way of determining whether we're trying to create a normal file,
  # and it's here so that the logic isn't visible in the content property.
  def should_be_file?
    return true if self[:ensure] == :file

    # I.e., it's set to something like "directory"
    return false if e = self[:ensure] and e != :present

    # The user doesn't really care, apparently
    if self[:ensure] == :present
      return true unless s = stat
      return(s.ftype == "file" ? true : false)
    end

    # If we've gotten here, then :ensure isn't set
    return true if self[:content]
    return true if stat and stat.ftype == "file"
    false
  end

  # Stat our file.  Depending on the value of the 'links' attribute, we
  # use either 'stat' or 'lstat', and we expect the properties to use the
  # resulting stat object accordingly (mostly by testing the 'ftype'
  # value).
  #
  # We use the initial value :needs_stat to ensure we only stat the file once,
  # but can also keep track of a failed stat (@stat == nil). This also allows
  # us to re-stat on demand by setting @stat = :needs_stat.
  def stat
    return @stat unless @stat == :needs_stat

    method = :stat

    # Files are the only types that support links
    if (self.class.name == :file and self[:links] != :follow) or self.class.name == :tidy
      method = :lstat
    end

    @stat = begin
      ::File.send(method, self[:path])
    rescue Errno::ENOENT => error
      nil
    rescue Errno::EACCES => error
      warning "Could not stat; permission denied"
      nil
    end
  end

  # We have to hack this just a little bit, because otherwise we'll get
  # an error when the target and the contents are created as properties on
  # the far side.
  def to_trans(retrieve = true)
    obj = super
    obj.delete(:target) if obj[:target] == :notlink
    obj
  end

  # Write out the file.  Requires the property name for logging.
  # Write will be done by the content property, along with checksum computation
  def write(property)
    remove_existing(:file)

    use_temporary_file = write_temporary_file?
    if use_temporary_file
      path = "#{self[:path]}.puppettmp_#{rand(10000)}"
      path = "#{self[:path]}.puppettmp_#{rand(10000)}" while ::File.exists?(path) or ::File.symlink?(path)
    else
      path = self[:path]
    end

    mode = self.should(:mode) # might be nil
    umask = mode ? 000 : 022
    mode_int = mode ? mode.to_i(8) : nil

    content_checksum = Puppet::Util.withumask(umask) { ::File.open(path, 'wb', mode_int ) { |f| write_content(f) } }

    # And put our new file in place
    if use_temporary_file # This is only not true when our file is empty.
      begin
        fail_if_checksum_is_wrong(path, content_checksum) if validate_checksum?
        ::File.rename(path, self[:path])
      rescue => detail
        fail "Could not rename temporary file #{path} to #{self[:path]}: #{detail}"
      ensure
        # Make sure the created file gets removed
        ::File.unlink(path) if FileTest.exists?(path)
      end
    end

    # make sure all of the modes are actually correct
    property_fix

  end

  private

  # Should we validate the checksum of the file we're writing?
  def validate_checksum?
    self[:checksum] !~ /time/
  end

  # Make sure the file we wrote out is what we think it is.
  def fail_if_checksum_is_wrong(path, content_checksum)
    newsum = parameter(:checksum).sum_file(path)
    return if [:absent, nil, content_checksum].include?(newsum)

    self.fail "File written to disk did not match checksum; discarding changes (#{content_checksum} vs #{newsum})"
  end

  # write the current content. Note that if there is no content property
  # simply opening the file with 'w' as done in write is enough to truncate
  # or write an empty length file.
  def write_content(file)
    (content = property(:content)) && content.write(file)
  end

  private

  def write_temporary_file?
    # unfortunately we don't know the source file size before fetching it
    # so let's assume the file won't be empty
    (c = property(:content) and c.length) || (s = @parameters[:source] and 1)
  end

  # There are some cases where all of the work does not get done on
  # file creation/modification, so we have to do some extra checking.
  def property_fix
    properties.each do |thing|
      next unless [:mode, :owner, :group, :seluser, :selrole, :seltype, :selrange].include?(thing.name)

      # Make sure we get a new stat objct
      @stat = :needs_stat
      currentvalue = thing.retrieve
      thing.sync unless thing.safe_insync?(currentvalue)
    end
  end
end

# We put all of the properties in separate files, because there are so many
# of them.  The order these are loaded is important, because it determines
# the order they are in the property lit.
require 'puppet/type/file/checksum'
require 'puppet/type/file/content'     # can create the file
require 'puppet/type/file/source'      # can create the file
require 'puppet/type/file/target'      # creates a different type of file
require 'puppet/type/file/ensure'      # can create the file
require 'puppet/type/file/owner'
require 'puppet/type/file/group'
require 'puppet/type/file/mode'
require 'puppet/type/file/type'
require 'puppet/type/file/selcontext'  # SELinux file context
require 'puppet/type/file/ctime'
require 'puppet/type/file/mtime'
