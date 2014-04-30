require 'puppet'
require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/base'
require 'puppet/util/checksums'

# A class that handles retrieving file metadata.
class Puppet::FileServing::Metadata < Puppet::FileServing::Base

  include Puppet::Util::Checksums

  extend Puppet::Indirector
  indirects :file_metadata, :terminus_class => :selector

  attr_reader :path, :owner, :group, :mode, :checksum_type, :checksum, :ftype, :destination

  PARAM_ORDER = [:mode, :ftype, :owner, :group]

  def checksum_type=(type)
    raise(ArgumentError, "Unsupported checksum type #{type}") unless respond_to?("#{type}_file")

    @checksum_type = type
  end

  class MetaStat
    extend Forwardable

    def initialize(stat, source_permissions = nil)
      @stat = stat
      @source_permissions_ignore = source_permissions == :ignore
    end

    def owner
      @source_permissions_ignore ? Process.euid : @stat.uid
    end

    def group
      @source_permissions_ignore ? Process.egid : @stat.gid
    end

    def mode
      @source_permissions_ignore ? 0644 : @stat.mode
    end

    def_delegators :@stat, :ftype
  end

  class WindowsStat < MetaStat
    if Puppet.features.microsoft_windows?
      require 'puppet/util/windows/security'
    end

    def initialize(stat, path, source_permissions = nil)
      super(stat, source_permissions)
      @path = path
    end

    { :owner => 'S-1-5-32-544',
      :group => 'S-1-0-0',
      :mode => 0644
    }.each do |method, default_value|
      define_method method do
        return default_value if @source_permissions_ignore

        # this code remains for when source_permissions is not set to :ignore
        begin
          Puppet::Util::Windows::Security.send("get_#{method}", @path) || default_value
        rescue Puppet::Util::Windows::Error => detail
          # Very carefully catch only this specific error that result from
          # trying to read permissions on a symlinked file that is on a volume
          # that does not support ACLs.
          #
          # Unfortunately readlink method will not return the target path when
          # the given path is not the symlink.
          #
          # For instance, consider:
          #   symlink c:\link points to c:\target
          #   FileSystem.readlink('c:/link') returns 'c:/target'
          #   FileSystem.readlink('c:/link/file') will NOT return 'c:/target/file'
          #
          # Since detecting this up front is costly, since the path in question
          # needs to be recursively split and tested at each depth in the path,
          # we catch the standard error that will result from trying to read a
          # file that doesn't have a DACL - 1336 is ERROR_INVALID_DACL
          #
          # Note that this affects any manually created symlinks as well as
          # paths like puppet:///modules
          return default_value if detail.code == 1336

          # Also handle a VirtualBox bug where ERROR_INVALID_FUNCTION is
          # returned when following a symlink to a volume that is not NTFS.
          # It appears that the VirtualBox file system is not propagating
          # the standard Win32 error code above like it should.
          #
          # Apologies to all who enter this code path at a later date
          if detail.code == 1 && Facter.value(:virtual) == 'virtualbox'
            return default_value
          end

          raise
        end
      end
    end
  end

  def collect_stat(path, source_permissions)
    stat = stat()

    if Puppet.features.microsoft_windows?
      WindowsStat.new(stat, path, source_permissions)
    else
      MetaStat.new(stat, source_permissions)
    end
  end

  # Retrieve the attributes for this file, relative to a base directory.
  # Note that Puppet::FileSystem.stat(path) raises Errno::ENOENT
  # if the file is absent and this method does not catch that exception.
  def collect(source_permissions = nil)
    real_path = full_path

    stat = collect_stat(real_path, source_permissions)
    @owner = stat.owner
    @group = stat.group
    @ftype = stat.ftype

    # We have to mask the mode, yay.
    @mode = stat.mode & 007777

    case stat.ftype
    when "file"
      @checksum = ("{#{@checksum_type}}") + send("#{@checksum_type}_file", real_path).to_s
    when "directory" # Always just timestamp the directory.
      @checksum_type = "ctime"
      @checksum = ("{#{@checksum_type}}") + send("#{@checksum_type}_file", path).to_s
    when "link"
      @destination = Puppet::FileSystem.readlink(real_path)
      @checksum = ("{#{@checksum_type}}") + send("#{@checksum_type}_file", real_path).to_s rescue nil
    else
      raise ArgumentError, "Cannot manage files of type #{stat.ftype}"
    end
  end

  def initialize(path,data={})
    @owner       = data.delete('owner')
    @group       = data.delete('group')
    @mode        = data.delete('mode')
    if checksum = data.delete('checksum')
      @checksum_type = checksum['type']
      @checksum      = checksum['value']
    end
    @checksum_type ||= Puppet[:digest_algorithm]
    @ftype       = data.delete('type')
    @destination = data.delete('destination')
    super(path,data)
  end

  def to_data_hash
    super.update(
      {
        'owner'        => owner,
        'group'        => group,
        'mode'         => mode,
        'checksum'     => {
          'type'   => checksum_type,
          'value'  => checksum
        },
        'type'         => ftype,
        'destination'  => destination,

      }
    )
  end

  def self.from_data_hash(data)
    new(data.delete('path'), data)
  end

  PSON.register_document_type('FileMetadata',self)
  def to_pson_data_hash
    {
      'document_type' => 'FileMetadata',
      'data'          => to_data_hash,
      'metadata'      => {
        'api_version' => 1
        }
    }
  end

  def to_pson(*args)
    to_pson_data_hash.to_pson(*args)
  end

  def self.from_pson(data)
    Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
    self.from_data_hash(data)
  end

end
