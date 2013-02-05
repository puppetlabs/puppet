require 'open-uri'
require 'net/ftp'
require 'bzip2'

Puppet::Type.type(:package).provide :freebsd, :parent => Puppet::Provider::Package do
  include Puppet::Util::Execution

  desc "The specific form of package management on FreeBSD. Resource names must be
  specified as the port origin: <port_category>/<port_name>."

  commands :pkginfo    => "/usr/sbin/pkg_info",
           :pkgadd     => "/usr/sbin/pkg_add",
           :pkgdelete  => "/usr/sbin/pkg_delete"

  confine :operatingsystem => :freebsd
  defaultfor :operatingsystem => :freebsd

  @@lock = Mutex.new
  @@ports_index = nil

  # fix bug in URI::FTP merge method that tries to set typecode
  # even when other is a string.
  class URI::FTP
    def merge(other)
      tmp = super(other)
      if self != tmp
        tmp.set_typecode(other.typecode) rescue NoMethodError
      end
      return tmp
    end
  end

  def self.parse_pkg_string(pkg_string)
    {
      :pkg_name => pkg_string.split("-").slice(0..-2).join("-"),
      :pkg_version => pkg_string.split("-")[-1],
    }
  end

  def self.unparse_pkg_info(pkg_info)
    [:pkg_name, :pkg_version].map { |key| pkg_info[key] }.join("-")
  end
  
  def self.parse_origin(origin_path)
    begin
      origin = {
        :port_category => origin_path.split("/").fetch(-2),
        :port_name     => origin_path.split("/").fetch(-1),
      }
    rescue IndexError
      raise Puppet::Error.new "#{origin_path}: not in required origin format: .*/<port_category>/<port_name>"
    end
    origin
  end

  def self.instances
    packages = []
    output = pkginfo "-aoQ"
    output.split("\n").each do |data|
      pkg_string, pkg_origin = data.split(":")
      pkg_info = self.parse_pkg_string(pkg_string)

      packages << new({
        :provider => self.name,
        :name     => pkg_origin,
        :ensure   => pkg_info[:pkg_version],
      })
    end
    packages
  end

  def ports_index
    @@lock.synchronize do
      if @@ports_index.nil?
        @@ports_index = {}
        uri = source.merge "INDEX.bz2"
        Puppet.debug "Fetching INDEX: #{uri.inspect}"
        begin
          Bzip2::Reader.open(uri) do |f|
            while (line = f.gets)
              fields = line.split("|")
              pkg_info = self.class.parse_pkg_string(fields[0])
              origin = self.class.parse_origin(fields[1])
              @@ports_index[origin] = pkg_info
            end
          end
        rescue IOError, OpenURI::HTTPError, Net::FTPError
          @@ports_index = nil
          raise Puppet::Error.new "Could not fetch ports INDEX: #{$!}"
        end
      end
    end
    @@ports_index
  end

  def uri_path
    Facter.loadfacts
    File.join(
      "/", "pub", "FreeBSD", "ports",
      Facter.value(:hardwareisa),
      [
        "packages",
        Facter.value(:kernelmajversion).split(".")[0],
        "stable",
      ].join("-")
    ) << "/"
  end

  def source
    if !defined? @source
      if @resource[:source]
        @source = URI.parse(@resource[:source])
        if @source.path.empty?
          @source.merge! uri_path
        end
      else # source parameter not set; build default source URI
        @source = URI::FTP.build({
          :host => "ftp.freebsd.org",
          :path => uri_path,
        })
      end
      Puppet.debug "Package: #{@resource[:name]}: source => #{@source.inspect}"
    end
    @source
  end

  def origin
    if !defined? @origin
      @origin = self.class.parse_origin(@resource[:name])
      Puppet.debug "Package: #{@resource[:name]}: origin => #{@origin.inspect}"
    end
    @origin
  end

  def package_uri
    begin
      pkg_name = self.class.unparse_pkg_info(ports_index.fetch(origin))
    rescue IndexError
      raise Puppet::Error.new "package not found in INDEX"
    end
    uri = source.merge File.join("All", pkg_name + ".tbz")
    Puppet.debug "Package: #{@resource[:name]}: package_uri => #{uri.inspect}"
    uri
  end

  def install
    should = @resource.should(:ensure)
    origin # call origin so we check the package name for correctness early

    # Source URI is for local file path.
    if !source.absolute? or source.scheme == "file"
      pkgadd source.path
    # Source URI is to specific package file
    elsif source.absolute? && source.path.end_with?(".tbz")
      pkgadd source.to_s
    # Source URI is to a package repository
    else
      pkgadd "-f", package_uri.to_s
    end
    nil
  end

  def query
    self.class.instances.each do |provider|
      if provider.name == @resource.name
        return provider.properties
      end
    end
    nil
  end

  def uninstall
    output = pkginfo "-qO", @resource[:name]
    output.split("\n").each { |pkg_name| pkgdelete([pkg_name]) }
  end
end
