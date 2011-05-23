require 'tmpdir'
require 'digest/md5'
require 'fileutils'

# Abstract
class Puppet::Provider::Vcsrepo < Puppet::Provider

  private

  def set_ownership
    owner = @resource.value(:owner) || nil
    group = @resource.value(:group) || nil
    FileUtils.chown_R(owner, group, @resource.value(:path))
  end

  def path_exists?
    File.directory?(@resource.value(:path))
  end

  # Note: We don't rely on Dir.chdir's behavior of automatically returning the
  # value of the last statement -- for easier stubbing.
  def at_path(&block) #:nodoc:
    value = nil
    Dir.chdir(@resource.value(:path)) do
      value = yield
    end
    value
  end

  def tempdir
    @tempdir ||= File.join(Dir.tmpdir, 'vcsrepo-' + Digest::MD5.hexdigest(@resource.value(:path)))
  end

end
