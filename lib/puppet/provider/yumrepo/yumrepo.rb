require 'fileutils'

begin
  require 'inifile'
rescue
  Puppet.warning "The inifile gem is required for Yumrepo"
end

Puppet::Type.type(:yumrepo).provide(:yumrepo) do
  desc "Manage yum repositories"

  def create
    desired_yumconfig.write unless self.exists?
  end

  def destroy
    File.rm resource[:path] if self.exists? 
  end

  def exists?
    desired_yumconfig == current_yumconfig
  end

  def desired_yumconfig
    yumconfig = IniFile.new(:filename => "/etc/yum.repos.d/#{resource.name}.repo", :comment => '#', :parameter => '=')
    section = resource[:name]

    options = [
      :baseurl,
      :descr,
      :enabled,
      :enablegroups,
      :exclude,
      :failovermethod,
      :gpgcheck,
      :gpgkey,
      :includepkgs,
      :http_caching,
      :keepalive,
      :metadata_expire,
      :mirrorlist,
      :priority,
      :protect,
      :proxy,
      :proxy_password,
      :proxy_username,
      :timeout,
    ]

    options.each do |option|
      if resource[option].nil?
        next
      else
        yumconfig[section][option.to_s] = resource[option].to_s
      end
    end

    return yumconfig
  end

  def current_yumconfig
    yumconfig = IniFile.load("/etc/yum.repos.d/#{resource.name}.repo", :comment => '#', :parameter => '=')
  end
end  
