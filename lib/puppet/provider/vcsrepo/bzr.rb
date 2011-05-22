require File.join(File.dirname(__FILE__), '..', 'vcsrepo')

Puppet::Type.type(:vcsrepo).provide(:bzr, :parent => Puppet::Provider::Vcsrepo) do
  desc "Supports Bazaar repositories"

  commands   :bzr => 'bzr'
  defaultfor :bzr => :exists
  has_features :reference_tracking

  def create
    if !@resource.value(:source)
      create_repository(@resource.value(:path))
    else
      clone_repository(@resource.value(:revision))
    end
  end

  def exists?
    File.directory?(File.join(@resource.value(:path), '.bzr'))
  end

  def destroy
    FileUtils.rm_rf(@resource.value(:path))
  end
  
  def revision
    at_path do
      current_revid = bzr('version-info')[/^revision-id:\s+(\S+)/, 1]
      desired = @resource.value(:revision)
      begin
        desired_revid = bzr('revision-info', desired).strip.split(/\s+/).last
      rescue Puppet::ExecutionFailure
        # Possible revid available during update (but definitely not current)
        desired_revid = nil
      end
      if current_revid == desired_revid
        desired
      else
        current_revid
      end
    end
  end

  def revision=(desired)
    bzr('update', '-r', desired, @resource.value(:path))
  end

  private

  def create_repository(path)
    bzr('init', path)
  end

  def clone_repository(revision)
    args = ['branch']
    if revision
      args.push('-r', revision)
    end
    args.push(@resource.value(:source),
              @resource.value(:path))
    bzr(*args)
  end

end
