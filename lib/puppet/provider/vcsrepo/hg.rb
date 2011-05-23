require File.join(File.dirname(__FILE__), '..', 'vcsrepo')

Puppet::Type.type(:vcsrepo).provide(:hg, :parent => Puppet::Provider::Vcsrepo) do
  desc "Supports Mercurial repositories"

  commands   :hg => 'hg'
  defaultfor :hg => :exists
  has_features :reference_tracking

  def create
    if !@resource.value(:source)
      create_repository(@resource.value(:path))
    else
      clone_repository(@resource.value(:revision))
    end
    update_owner
  end

  def working_copy_exists?
    File.directory?(File.join(@resource.value(:path), '.hg'))
  end

  def exists?
    working_copy_exists?
  end

  def destroy
    FileUtils.rm_rf(@resource.value(:path))
  end

  def latest?
    at_path do
      return self.revision == self.latest
    end
  end

  def latest
    at_path do
      begin
        hg('incoming', '--branch', '.', '--newest-first', '--limit', '1')[/^changeset:\s+(?:-?\d+):(\S+)/m, 1]
      rescue Puppet::ExecutionFailure
        # If there are no new changesets, return the current nodeid
        self.revision
      end
    end
  end

  def revision
    at_path do
      current = hg('parents')[/^changeset:\s+(?:-?\d+):(\S+)/m, 1]
      desired = @resource.value(:revision)
      if desired
        # Return the tag name if it maps to the current nodeid
        mapped = hg('tags')[/^#{Regexp.quote(desired)}\s+\d+:(\S+)/m, 1]
        if current == mapped
          desired
        else
          current
        end
      else
        current
      end
    end
  end

  def revision=(desired)
    at_path do
      hg('pull')
      begin
        hg('merge')
      rescue Puppet::ExecutionFailure
        # If there's nothing to merge, just skip
      end
      hg('update', '--clean', '-r', desired)
    end
    update_owner
  end

  private

  def create_repository(path)
    hg('init', path)
  end

  def clone_repository(revision)
    args = ['clone']
    if revision
      args.push('-u', revision)
    end
    args.push(@resource.value(:source),
              @resource.value(:path))
    hg(*args)
  end

  def update_owner
    if @resource.value(:owner) or @resource.value(:group)
      set_ownership
    end
  end

end
