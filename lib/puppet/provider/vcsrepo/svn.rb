require File.join(File.dirname(__FILE__), '..', 'vcsrepo')

Puppet::Type.type(:vcsrepo).provide(:svn, :parent => Puppet::Provider::Vcsrepo) do
  desc "Supports Subversion repositories"

  commands :svn      => 'svn',
           :svnadmin => 'svnadmin'

  defaultfor :svn => :exists
  has_features :filesystem_types, :reference_tracking

  def create
    if !@resource.value(:source)
      create_repository(@resource.value(:path))
    else
      checkout_repository(@resource.value(:source),
                          @resource.value(:path),
                          @resource.value(:revision))
    end
  end

  def working_copy_exists?
    File.directory?(File.join(@resource.value(:path), '.svn'))
  end

  def exists?
    working_copy_exists?
  end

  def destroy
    FileUtils.rm_rf(@resource.value(:path))
  end

  def latest?
    at_path do
      if self.revision < self.latest then
        return false
      else
        return true
      end
    end
  end

  def latest
    at_path do
      svn('info', '-r', 'HEAD')[/^Revision:\s+(\d+)/m, 1]
    end
  end
  
  def revision
    at_path do
      svn('info')[/^Revision:\s+(\d+)/m, 1]
    end
  end

  def revision=(desired)
    at_path do
      svn('update', '-r', desired)
    end
  end

  private

  def checkout_repository(source, path, revision = nil)
    args = ['checkout']
    if revision
      args.push('-r', revision)
    end
    args.push(source, path)
    svn(*args)
  end

  def create_repository(path)
    args = ['create']
    if @resource.value(:fstype)
      args.push('--fs-type', @resource.value(:fstype))
    end
    args << path
    svnadmin(*args)
  end

end
