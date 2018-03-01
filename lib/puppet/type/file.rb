require 'digest/md5'
require 'cgi'
require 'etc'
require 'uri'
require 'fileutils'
require 'enumerator'
require 'pathname'
require 'puppet/parameter/boolean'
require 'puppet/util/diff'
require 'puppet/util/checksums'
require 'puppet/util/backups'
require 'puppet/util/symbolic_file_mode'

Puppet::Type.newtype(:file) do
  include Puppet::Util::MethodHelper
  include Puppet::Util::Checksums
  include Puppet::Util::Backups
  include Puppet::Util::SymbolicFileMode

  @doc = "Manages files, including their content, ownership, and permissions.

    The `file` type can manage normal files, directories, and symlinks; the
    type should be specified in the `ensure` attribute.

    File contents can be managed directly with the `content` attribute, or
    downloaded from a remote source using the `source` attribute; the latter
    can also be used to recursively serve directories (when the `recurse`
    attribute is set to `true` or `local`). On Windows, note that file
    contents are managed in binary mode; Puppet never automatically translates
    line endings.

    **Autorequires:** If Puppet is managing the user or group that owns a
    file, the file resource will autorequire them. If Puppet is managing any
    parent directories of a file, the file resource will autorequire them."

  feature :manages_symlinks,
    "The provider can manage symbolic links."

  def self.title_patterns
    # strip trailing slashes from path but allow the root directory, including
    # for example "/" or "C:/"
    [ [ %r{^(/|.+:/|.*[^/])/*\Z}m, [ [ :path ] ] ] ]
  end

  newparam(:path) do
    desc <<-'EOT'
      The path to the file to manage.  Must be fully qualified.

      On Windows, the path should include the drive letter and should use `/` as
      the separator character (rather than `\\`).
    EOT
    isnamevar

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        fail Puppet::Error, _("File paths must be fully qualified, not '%{path}'") % { path: value }
      end
    end

    munge do |value|
      if value.start_with?('//') and ::File.basename(value) == "/"
        # This is a UNC path pointing to a share, so don't add a trailing slash
        ::File.expand_path(value)
      else
        ::File.join(::File.split(::File.expand_path(value)))
      end
    end
  end

  newparam(:backup) do
    desc <<-EOT
      Whether (and how) file content should be backed up before being replaced.
      This attribute works best as a resource default in the site manifest
      (`File { backup => main }`), so it can affect all file resources.

      * If set to `false`, file content won't be backed up.
      * If set to a string beginning with `.`, such as `.puppet-bak`, Puppet will
        use copy the file in the same directory with that value as the extension
        of the backup. (A value of `true` is a synonym for `.puppet-bak`.)
      * If set to any other string, Puppet will try to back up to a filebucket
        with that title. See the `filebucket` resource type for more details.
        (This is the preferred method for backup, since it can be centralized
        and queried.)

      Default value: `puppet`, which backs up to a filebucket of the same name.
      (Puppet automatically creates a **local** filebucket named `puppet` if one
      doesn't already exist.)

      Backing up to a local filebucket isn't particularly useful. If you want
      to make organized use of backups, you will generally want to use the
      puppet master server's filebucket service. This requires declaring a
      filebucket resource and a resource default for the `backup` attribute
      in site.pp:

          # /etc/puppetlabs/puppet/manifests/site.pp
          filebucket { 'main':
            path   => false,                # This is required for remote filebuckets.
            server => 'puppet.example.com', # Optional; defaults to the configured puppet master.
          }

          File { backup => main, }

      If you are using multiple puppet master servers, you will want to
      centralize the contents of the filebucket. Either configure your load
      balancer to direct all filebucket traffic to a single master, or use
      something like an out-of-band rsync task to synchronize the content on all
      masters.
    EOT

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
        self.fail _("Invalid backup type %{value}") % { value: value.inspect }
      end
    end
  end

  newparam(:recurse) do
    desc "Whether to recursively manage the _contents_ of a directory. This attribute
      is only used when `ensure => directory` is set. The allowed values are:

      * `false` --- The default behavior. The contents of the directory will not be
        automatically managed.
      * `remote` --- If the `source` attribute is set, Puppet will automatically
        manage the contents of the source directory (or directories), ensuring
        that equivalent files and directories exist on the target system and
        that their contents match.

        Using `remote` will disable the `purge` attribute, but results in faster
        catalog application than `recurse => true`.

        The `source` attribute is mandatory when `recurse => remote`.
      * `true` --- If the `source` attribute is set, this behaves similarly to
        `recurse => remote`, automatically managing files from the source directory.

        This also enables the `purge` attribute, which can delete unmanaged
        files from a directory. See the description of `purge` for more details.

        The `source` attribute is not mandatory when using `recurse => true`, so you
        can enable purging in directories where all files are managed individually.

      By default, setting recurse to `remote` or `true` will manage _all_
      subdirectories. You can use the `recurselimit` attribute to limit the
      recursion depth.
    "

    newvalues(:true, :false, :remote)

    validate { |arg| }
    munge do |value|
      newval = super(value)
      case newval
      when :true; true
      when :false; false
      when :remote; :remote
      else
        self.fail _("Invalid recurse value %{value}") % { value: value.inspect }
      end
    end
  end

  newparam(:recurselimit) do
    desc "How far Puppet should descend into subdirectories, when using
      `ensure => directory` and either `recurse => true` or `recurse => remote`.
      The recursion limit affects which files will be copied from the `source`
      directory, as well as which files can be purged when `purge => true`.

      Setting `recurselimit => 0` is the same as setting `recurse => false` ---
      Puppet will manage the directory, but all of its contents will be treated
      as unmanaged.

      Setting `recurselimit => 1` will manage files and directories that are
      directly inside the directory, but will not manage the contents of any
      subdirectories.

      Setting `recurselimit => 2` will manage the direct contents of the
      directory, as well as the contents of the _first_ level of subdirectories.

      This pattern continues for each incremental value of `recurselimit`."

    newvalues(/^[0-9]+$/)

    munge do |value|
      newval = super(value)
      case newval
      when Integer; value
      when /^\d+$/; Integer(value)
      else
        self.fail _("Invalid recurselimit value %{value}") % { value: value.inspect }
      end
    end
  end

  newparam(:replace, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Whether to replace a file or symlink that already exists on the local system but
      whose content doesn't match what the `source` or `content` attribute
      specifies.  Setting this to false allows file resources to initialize files
      without overwriting future changes.  Note that this only affects content;
      Puppet will still manage ownership and permissions. Defaults to `true`."
    defaultto :true
  end

  newparam(:force, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Perform the file operation even if it will destroy one or more directories.
      You must use `force` in order to:

      * `purge` subdirectories
      * Replace directories with files or links
      * Remove a directory when `ensure => absent`"
    defaultto false
  end

  newparam(:ignore) do
    desc "A parameter which omits action on files matching
      specified patterns during recursion.  Uses Ruby's builtin globbing
      engine, so shell metacharacters such as `[a-z]*` are fully supported.
      Matches that would descend into the directory structure are ignored,
      such as `*/*`."

    validate do |value|
      unless value.is_a?(Array) or value.is_a?(String) or value == false
        self.devfail "Ignore must be a string or an Array"
      end
    end
  end

  newparam(:links) do
    desc "How to handle links during file actions.  During file copying,
      `follow` will copy the target file instead of the link and `manage`
      will copy the link itself. When not copying, `manage` will manage
      the link, and `follow` will manage the file to which the link points."

    newvalues(:follow, :manage)

    defaultto :manage
  end

  newparam(:purge, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Whether unmanaged files should be purged. This option only makes
      sense when `ensure => directory` and `recurse => true`.

      * When recursively duplicating an entire directory with the `source`
        attribute, `purge => true` will automatically purge any files
        that are not in the source directory.
      * When managing files in a directory as individual resources,
        setting `purge => true` will purge any files that aren't being
        specifically managed.

      If you have a filebucket configured, the purged files will be uploaded,
      but if you do not, this will destroy data.

      Unless `force => true` is set, purging will **not** delete directories,
      although it will delete the files they contain.

      If `recurselimit` is set and you aren't using `force => true`, purging
      will obey the recursion limit; files in any subdirectories deeper than the
      limit will be treated as unmanaged and left alone."

    defaultto :false
  end

  newparam(:sourceselect) do
    desc "Whether to copy all valid sources, or just the first one.  This parameter
      only affects recursive directory copies; by default, the first valid
      source is the only one used, but if this parameter is set to `all`, then
      all valid sources will have all of their contents copied to the local
      system. If a given file exists in more than one source, the version from
      the earliest source in the list will be used."

    defaultto :first

    newvalues(:first, :all)
  end

  newparam(:show_diff, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Whether to display differences when the file changes, defaulting to
        true.  This parameter is useful for files that may contain passwords or
        other secret data, which might otherwise be included in Puppet reports or
        other insecure outputs.  If the global `show_diff` setting
        is false, then no diffs will be shown even if this parameter is true."

    defaultto :true
  end

  newparam(:validate_cmd) do
    desc "A command for validating the file's syntax before replacing it. If
      Puppet would need to rewrite a file due to new `source` or `content`, it
      will check the new content's validity first. If validation fails, the file
      resource will fail.

      This command must have a fully qualified path, and should contain a
      percent (`%`) token where it would expect an input file. It must exit `0`
      if the syntax is correct, and non-zero otherwise. The command will be
      run on the target system while applying the catalog, not on the puppet master.

      Example:

          file { '/etc/apache2/apache2.conf':
            content      => 'example',
            validate_cmd => '/usr/sbin/apache2 -t -f %',
          }

      This would replace apache2.conf only if the test returned true.

      Note that if a validation command requires a `%` as part of its text,
      you can specify a different placeholder token with the
      `validate_replacement` attribute."
  end

  newparam(:validate_replacement) do
    desc "The replacement string in a `validate_cmd` that will be replaced
      with an input file name. Defaults to: `%`"

    defaultto '%'
  end

  # Autorequire the nearest ancestor directory found in the catalog.
  autorequire(:file) do
    req = []
    path = Pathname.new(self[:path])
    if !path.root?
      # Start at our parent, to avoid autorequiring ourself
      parents = path.parent.enum_for(:ascend)
      if found = parents.find { |p| catalog.resource(:file, p.to_s) }
        req << found.to_s
      end
    end
    # if the resource is a link, make sure the target is created first
    req << self[:target] if self[:target]
    req
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

    self.fail _("You cannot specify more than one of %{creators}") % { creators: CREATORS.collect { |p| p.to_s}.join(", ") } if creator_count > 1

    self.fail _("You cannot specify a remote recursion without a source") if !self[:source] && self[:recurse] == :remote

    self.fail _("You cannot specify source when using checksum 'none'") if self[:checksum] == :none && !self[:source].nil?

    SOURCE_ONLY_CHECKSUMS.each do |checksum_type|
      self.fail _("You cannot specify content when using checksum '%{checksum_type}'") % { checksum_type: checksum_type } if self[:checksum] == checksum_type && !self[:content].nil?
    end

    self.warning _("Possible error: recurselimit is set but not recurse, no recursion will happen") if !self[:recurse] && self[:recurselimit]

    if @parameters[:content] && @parameters[:content].actual_content
      # Now that we know the checksum, update content (in case it was created before checksum was known).
      @parameters[:content].value = @parameters[:checksum].sum(@parameters[:content].actual_content)
    end

    if self[:checksum] && self[:checksum_value] && !send("#{self[:checksum]}?", self[:checksum_value])
      self.fail _("Checksum value '%{value}' is not a valid checksum type %{checksum}") % { value: self[:checksum_value], checksum: self[:checksum] }
    end

    self.warning _("Checksum value is ignored unless content or source are specified") if self[:checksum_value] && !self[:content] && !self[:source]

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
    if self.should(:owner) && ! self.should(:owner).is_a?(Symbol)
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
      fail _("Can not find filebucket for backups without a catalog")
    end

    unless catalog and filebucket = catalog.resource(:filebucket, backup) or backup == "puppet"
      fail _("Could not find filebucket %{backup} specified in backup") % { backup: backup }
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

  def present?(current_values)
    super && current_values[:ensure] != :false
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
        self[:ensure] = :link
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

    # REVISIT: sort_by is more efficient?
    result = children.values.sort { |a, b| a[:path] <=> b[:path] }
    remove_less_specific_files(result)
  end

  def remove_less_specific_files(files)
    existing_files = catalog.vertices.select { |r| r.is_a?(self.class) }
    self.class.remove_less_specific_files(files, self[:path], existing_files) do |file|
      file[:path]
    end
  end

  # This is to fix bug #2296, where two files recurse over the same
  # set of files.  It's a rare case, and when it does happen you're
  # not likely to have many actual conflicts, which is good, because
  # this is a pretty inefficient implementation.
  def self.remove_less_specific_files(files, parent_path, existing_files, &block)
    # REVISIT: is this Windows safe?  AltSeparator?
    mypath = parent_path.split(::File::Separator)
    other_paths = existing_files.
      select { |r| (yield r) != parent_path}.
      collect { |r| (yield r).split(::File::Separator) }.
      select  { |p| p[0,mypath.length]  == mypath }

    return files if other_paths.empty?

    files.reject { |file|
      path = (yield file).split(::File::Separator)
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
    recurse_remote_metadata.each do |meta|
      if meta.relative_path == "."
        self[:checksum] = meta.checksum_type
        parameter(:source).metadata = meta
        next
      end
      children[meta.relative_path] ||= newchild(meta.relative_path)
      children[meta.relative_path][:source] = meta.source
      children[meta.relative_path][:checksum] = meta.checksum_type
      children[meta.relative_path].parameter(:source).metadata = meta
    end

    children
  end

  def recurse_remote_metadata
    sourceselect = self[:sourceselect]

    total = self[:source].collect do |source|
      # For each inlined file resource, the catalog contains a hash mapping
      # source path to lists of metadata returned by a server-side search.
      if recursive_metadata = catalog.recursive_metadata[title]
        result = recursive_metadata[source]
      else
        result = perform_recursion(source)
      end

      next unless result
      return [] if top = result.find { |r| r.relative_path == "." } and top.ftype != "directory"
      result.each do |data|
        if data.relative_path == '.'
          data.source = source
        else
          # REMIND: appending file paths to URL may not be safe, e.g. foo+bar
          data.source = "#{source}/#{data.relative_path}"
        end
      end
      break result if result and ! result.empty? and sourceselect == :first
      result
    end.flatten.compact

    # This only happens if we have sourceselect == :all
    unless sourceselect == :first
      found = []
      total.reject! do |data|
        result = found.include?(data.relative_path)
        found << data.relative_path unless result
        result
      end
    end

    total
  end

  def perform_recursion(path)
    Puppet::FileServing::Metadata.indirection.search(
      path,
      :links => self[:links],
      :recurse => (self[:recurse] == :remote ? true : self[:recurse]),
      :recurselimit => self[:recurselimit],
      :source_permissions => self[:source_permissions],
      :ignore => self[:ignore],
      :checksum_type => (self[:source] || self[:content]) ? self[:checksum] : :none,
      :environment => catalog.environment_instance
    )
  end

  # Back up and remove the file or directory at `self[:path]`.
  #
  # @param  [Symbol] should The file type replacing the current content.
  # @return [Boolean] True if the file was removed, else False
  # @raises [fail???] If the file could not be backed up or could not be removed.
  def remove_existing(should)
    wanted_type = should.to_s
    current_type = read_current_type

    if current_type.nil?
      return false
    end

    if self[:backup]
      if can_backup?(current_type)
        backup_existing
      else
        self.warning _("Could not back up file of type %{current_type}") % { current_type: current_type }
      end
    end

    if wanted_type != "link" and current_type == wanted_type
      return false
    end

    case current_type
    when "directory"
      return remove_directory(wanted_type)
    when "link", "file", "fifo", "socket"
      return remove_file(current_type, wanted_type)
    else
      # Including: “blockSpecial”, “characterSpecial”, “unknown”
      self.fail _("Could not remove files of type %{current_type}") % { current_type: current_type }
    end
  end

  def retrieve
    # This check is done in retrieve to ensure it happens before we try to use
    # metadata in `copy_source_values`, but so it only fails the resource and not
    # catalog validation (because that would be a breaking change from Puppet 4).
    if Puppet.features.microsoft_windows? && parameter(:source) &&
      [:use, :use_when_creating].include?(self[:source_permissions])
      #TRANSLATORS "source_permissions => ignore" should not be translated
      err_msg = _("Copying owner/mode/group from the source file on Windows is not supported; use source_permissions => ignore.")
      if self[:owner] == nil || self[:group] == nil || self[:mode] == nil
        # Fail on Windows if source permissions are being used and the file resource
        # does not have mode owner, group, and mode all set (which would take precedence).
        self.fail err_msg
      else
        # Warn if use source permissions is specified on Windows
        self.warning err_msg
      end
    end

    # `checksum_value` implies explicit management of all metadata, so skip metadata
    # retrieval. Otherwise, if source is set, retrieve metadata for source.
    if (source = parameter(:source)) && property(:checksum_value).nil?
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
      Puppet::FileSystem.send(method, self[:path])
    rescue Errno::ENOENT
      nil
    rescue Errno::ENOTDIR
      nil
    rescue Errno::EACCES
      warning _("Could not stat; permission denied")
      nil
    end
  end

  def to_resource
    resource = super
    resource.delete(:target) if resource[:target] == :notlink
    resource
  end

  # Write out the file. To write content, pass the property as an argument
  # to delegate writing to; must implement a #write method that takes the file
  # as an argument.
  def write(property = nil)
    remove_existing(:file)

    mode = self.should(:mode) # might be nil
    mode_int = mode ? symbolic_mode_to_int(mode, Puppet::Util::DEFAULT_POSIX_MODE) : nil

    if write_temporary_file?
      Puppet::Util.replace_file(self[:path], mode_int) do |file|
        file.binmode
        devfail 'a property should have been provided if write_temporary_file? returned true' if property.nil?
        content_checksum = property.write(file)
        file.flush
        begin
          file.fsync
        rescue NotImplementedError
          # fsync may not be implemented by Ruby on all platforms, but
          # there is absolutely no recovery path if we detect that.  So, we just
          # ignore the return code.
          #
          # However, don't be fooled: that is accepting that we are running in
          # an unsafe fashion.  If you are porting to a new platform don't stub
          # that out.
        end

        fail_if_checksum_is_wrong(file.path, content_checksum) if validate_checksum?
        if self[:validate_cmd]
          output = Puppet::Util::Execution.execute(self[:validate_cmd].gsub(self[:validate_replacement], file.path), :failonfail => true, :combine => true)
          output.split(/\n/).each { |line|
            self.debug(line)
          }
        end
      end
    else
      umask = mode ? 000 : 022
      Puppet::Util.withumask(umask) { ::File.open(self[:path], 'wb', mode_int ) { |f| property.write(f) if property } }
    end

    # make sure all of the modes are actually correct
    property_fix
  end

  private

  # Carry the context of sensitive parameters to the the properties that will actually handle that
  # sensitive data.
  #
  # The file type can accept file content from a number of origins and depending on the current
  # state of the system different properties will be responsible for synchronizing the file
  # content. This method handles the necessary mapping of originating parameters to the
  # responsible parameters.
  def set_sensitive_parameters(sensitive_parameters)
    # If we have content that's marked as sensitive but the file doesn't exist then the ensure
    # property will be responsible for syncing content, so we have to mark ensure as sensitive as well.
    if sensitive_parameters.include?(:content)
      # The `ensure` parameter is not guaranteed to be defined either and will be conditionally set when
      # the `content` property is set, so we need to force the creation of the `ensure` property to
      # set the sensitive context.
      newattr(:ensure).sensitive = true
    end

    # The source parameter isn't actually a property but works by injecting information into the
    # content property. In order to preserve the intended sensitive context we need to mark content
    # as sensitive as well.
    if sensitive_parameters.include?(:source)
      sensitive_parameters.delete(:source)
      parameter(:source).sensitive = true
      # The `source` parameter will generate the `content` property when the resource state is retrieved
      # but that's long after we've set the sensitive context. Force the early creation of the `content`
      # attribute so we can mark it as sensitive.
      newattr(:content).sensitive = true
      # As noted above, making the `content` property sensitive requires making the `ensure` property
      # sensitive as well.
      newattr(:ensure).sensitive = true
    end

    super(sensitive_parameters)
  end

  # @return [String] The type of the current file, cast to a string.
  def read_current_type
    stat_info = stat
    if stat_info
      stat_info.ftype.to_s
    else
      nil
    end
  end

  # @return [Boolean] If the current file should be backed up and can be backed up.
  def can_backup?(type)
    if type == "directory" and force?
      # (#18110) Directories cannot be removed without :force,
      # so it doesn't make sense to back them up unless removing with :force.
      true
    elsif type == "file" or type == "link"
      true
    else
      # Including: “blockSpecial”, “characterSpecial”, "fifo", "socket", “unknown”
      false
    end
  end

  # @return [Boolean] if the directory was removed (which is always true currently)
  # @api private
  def remove_directory(wanted_type)
    if force?
      debug "Removing existing directory for replacement with #{wanted_type}"
      FileUtils.rmtree(self[:path])
      stat_needed
      true
    else
      notice _("Not removing directory; use 'force' to override")
      false
    end
  end

  # @return [Boolean] if the file was removed (which is always true currently)
  # @api private
  def remove_file(current_type, wanted_type)
    debug "Removing existing #{current_type} for replacement with #{wanted_type}"
    Puppet::FileSystem.unlink(self[:path])
    stat_needed
    true
  end

  def stat_needed
    @stat = :needs_stat
  end

  # Back up the existing file at a given prior to it being removed
  # @api private
  # @raise [Puppet::Error] if the file backup failed
  # @return [void]
  def backup_existing
    unless perform_backup
      #TRANSLATORS refers to a file which could not be backed up
      raise Puppet::Error, _("Could not back up; will not remove")
    end
  end

  # Should we validate the checksum of the file we're writing?
  def validate_checksum?
    self[:checksum] !~ /time/
  end

  # Make sure the file we wrote out is what we think it is.
  def fail_if_checksum_is_wrong(path, content_checksum)
    newsum = parameter(:checksum).sum_file(path)
    return if [:absent, nil, content_checksum].include?(newsum)

    self.fail _("File written to disk did not match checksum; discarding changes (%{content_checksum} vs %{newsum})") % { content_checksum: content_checksum, newsum: newsum }
  end

  def write_temporary_file?
    # Unfortunately we don't know the source file size before fetching it so
    # let's assume the file won't be empty. Why isn't it part of the metadata?
    (c = property(:content) and c.length) || @parameters[:source]
  end

  # There are some cases where all of the work does not get done on
  # file creation/modification, so we have to do some extra checking.
  def property_fix
    properties.each do |thing|
      next unless [:mode, :owner, :group, :seluser, :selrole, :seltype, :selrange].include?(thing.name)

      # Make sure we get a new stat object
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
require 'puppet/type/file/checksum_value' # can create the file, in place of content
require 'puppet/type/file/target'      # creates a different type of file
require 'puppet/type/file/ensure'      # can create the file
require 'puppet/type/file/owner'
require 'puppet/type/file/group'
require 'puppet/type/file/mode'
require 'puppet/type/file/type'
require 'puppet/type/file/selcontext'  # SELinux file context
require 'puppet/type/file/ctime'
require 'puppet/type/file/mtime'
