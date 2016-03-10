require 'puppet'
require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/base'
require 'puppet/util/checksums'
require 'uri'

# A class that handles retrieving file metadata.
class Puppet::FileServing::Metadata < Puppet::FileServing::Base

  include Puppet::Util::Checksums

  extend Puppet::Indirector
  indirects :file_metadata, :terminus_class => :selector

  attr_reader :path, :owner, :group, :mode, :checksum_type, :checksum, :ftype, :destination, :source_permissions, :content_uri

  PARAM_ORDER = [:mode, :ftype, :owner, :group]

  def checksum_type=(type)
    raise(ArgumentError, "Unsupported checksum type #{type}") unless Puppet::Util::Checksums.respond_to?("#{type}_file")

    @checksum_type = type
  end

  def source_permissions=(source_permissions)
    raise(ArgumentError, "Unsupported source_permission #{source_permissions}") unless [:use, :use_when_creating, :ignore].include?(source_permissions.intern)

    @source_permissions = source_permissions.intern
  end

  def content_uri=(path)
    begin
      uri = URI.parse(URI.escape(path))
    rescue URI::InvalidURIError => detail
      raise(ArgumentError, "Could not understand URI #{path}: #{detail}")
    end
    raise(ArgumentError, "Cannot use opaque URLs '#{path}'") unless uri.hierarchical?
    raise(ArgumentError, "Must use URLs of type puppet as content URI") if uri.scheme != "puppet"

    @content_uri = path
  end

  class MetaStat
    extend Forwardable

    def initialize(stat, source_permissions)
      @stat = stat
      @source_permissions_ignore = (!source_permissions || source_permissions == :ignore)
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

    def initialize(stat, path, source_permissions)
      super(stat, source_permissions)
      @path = path
      raise(ArgumentError, "Unsupported Windows source permissions option #{source_permissions}") unless @source_permissions_ignore
    end

    { :owner => 'S-1-5-32-544',
      :group => 'S-1-0-0',
      :mode => 0644
    }.each do |method, default_value|
      define_method method do
        return default_value
      end
    end
  end

  def collect_stat(path)
    stat = stat()

    if Puppet.features.microsoft_windows?
      WindowsStat.new(stat, path, @source_permissions)
    else
      MetaStat.new(stat, @source_permissions)
    end
  end

  # Retrieve the attributes for this file, relative to a base directory.
  # Note that Puppet::FileSystem.stat(path) raises Errno::ENOENT
  # if the file is absent and this method does not catch that exception.
  def collect(source_permissions = nil)
    real_path = full_path

    stat = collect_stat(real_path)
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
    @source      = data.delete('source')
    @content_uri = data.delete('content_uri')
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
      }.merge(content_uri ? {'content_uri' => content_uri} : {})
       .merge(source ? {'source' => source} : {})
    )
  end

  def self.from_data_hash(data)
    new(data.delete('path'), data)
  end

end
