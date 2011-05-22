require File.join(File.dirname(__FILE__), '..', 'vcsrepo')

Puppet::Type.type(:vcsrepo).provide(:git, :parent => Puppet::Provider::Vcsrepo) do
  desc "Supports Git repositories"

  ##TODO modify the commands below so that the su - is included
  commands :git => 'git'
  defaultfor :git => :exists
  has_features :bare_repositories, :reference_tracking

  def create
    if !@resource.value(:source)
      init_repository(@resource.value(:path))
    else
      clone_repository(@resource.value(:source), @resource.value(:path))
      if @resource.value(:revision)
        if @resource.value(:ensure) == :bare
          notice "Ignoring revision for bare repository"
        else
          checkout_or_reset
        end
      end
      if @resource.value(:ensure) != :bare
        update_submodules
      end
    end
    update_owner_and_excludes
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
    branch = on_branch?
    if branch == 'master'
      return get_revision('origin/HEAD')
    else
        return get_revision('origin/%s' % branch)
    end
  end

  def revision
    update_references
    current   = at_path { git('rev-parse', 'HEAD') }
    canonical = at_path { git('rev-parse', @resource.value(:revision)) }
    if current == canonical
      @resource.value(:revision)
    else
      current
    end
  end

  def revision=(desired)
    checkout_or_reset(desired)
    if local_branch_revision?(desired)
      # reset instead of pull to avoid merge conflicts. assuming remote is
      # authoritative.
      # might be worthwhile to have an allow_local_changes param to decide
      # whether to reset or pull when we're ensuring latest.
      at_path { git('reset', '--hard', "origin/#{desired}") }
    end
    if @resource.value(:ensure) != :bare
      update_submodules
    end
    update_owner_and_excludes
  end

  def bare_exists?
    bare_git_config_exists? && !working_copy_exists?
  end

  def working_copy_exists?
    File.directory?(File.join(@resource.value(:path), '.git'))
  end

  def exists?
    working_copy_exists? || bare_exists?
  end

  def update_references
    at_path do
      git('fetch', '--tags', 'origin')
    end
  end

  private

  def bare_git_config_exists?
    File.exist?(File.join(@resource.value(:path), 'config'))
  end

  def clone_repository(source, path)
    check_force
    args = ['clone']
    if @resource.value(:ensure) == :bare
      args << '--bare'
    end
    if !File.exist?(File.join(@resource.value(:path), '.git'))
      args.push(source, path)
      git(*args)
    else
      notice "Repo has already been cloned"
    end
  end

  def check_force
    if path_exists?
      if @resource.value(:force)
        notice "Removing %s to replace with vcsrepo." % @resource.value(:path)
        destroy
      else
        raise Puppet::Error, "Could not create repository (non-repository at path)"
      end
    end
  end

  def init_repository(path)
    check_force
    if @resource.value(:ensure) == :bare && working_copy_exists?
      convert_working_copy_to_bare
    elsif @resource.value(:ensure) == :present && bare_exists?
      convert_bare_to_working_copy
    else
      # normal init
      FileUtils.mkdir(@resource.value(:path))
      args = ['init']
      if @resource.value(:ensure) == :bare
        args << '--bare'
      end
      at_path do
        git(*args)
      end
    end
  end

  # Convert working copy to bare
  #
  # Moves:
  #   <path>/.git
  # to:
  #   <path>/
  def convert_working_copy_to_bare
    notice "Converting working copy repository to bare repository"
    FileUtils.mv(File.join(@resource.value(:path), '.git'), tempdir)
    FileUtils.rm_rf(@resource.value(:path))
    FileUtils.mv(tempdir, @resource.value(:path))
  end

  # Convert bare to working copy
  #
  # Moves:
  #   <path>/
  # to:
  #   <path>/.git
  def convert_bare_to_working_copy
    notice "Converting bare repository to working copy repository"
    FileUtils.mv(@resource.value(:path), tempdir)
    FileUtils.mkdir(@resource.value(:path))
    FileUtils.mv(tempdir, File.join(@resource.value(:path), '.git'))
    if commits_in?(File.join(@resource.value(:path), '.git'))
      reset('HEAD')
      git('checkout', '-f')
      update_owner_and_excludes
    end
  end

  def commits_in?(dot_git)
    Dir.glob(File.join(dot_git, 'objects/info/*'), File::FNM_DOTMATCH) do |e|
      return true unless %w(. ..).include?(File::basename(e))
    end
    false
  end

  def checkout_or_reset(revision = @resource.value(:revision))
    if local_branch_revision? 
      reset(revision)
    elsif tag_revision?
      at_path { git('checkout', '-b', revision) }
    elsif remote_branch_revision?
      at_path { git('checkout', '-b', revision, '--track', "origin/#{revision}") }
    end
  end

  def reset(desired)
    at_path do
      git('reset', '--hard', desired)
    end
  end

  def update_submodules
    at_path do
      git('submodule', 'init')
      git('submodule', 'update')
      git('submodule', 'foreach', 'git', 'submodule', 'init')
      git('submodule', 'foreach', 'git', 'submodule', 'update')
    end
  end

  def remote_branch_revision?(revision = @resource.value(:revision))
    # git < 1.6 returns 'origin/#{revision}'
    # git 1.6+ returns 'remotes/origin/#{revision}'
    at_path { branches.grep /(remotes\/)?origin\/#{revision}/ }
  end

  def local_branch_revision?(revision = @resource.value(:revision))
    at_path { branches.include?(revision) }
  end

  def tag_revision?(revision = @resource.value(:revision))
    at_path { tags.include?(revision) }
  end

  def branches
    at_path { git('branch', '-a') }.gsub('*', ' ').split(/\n/).map { |line| line.strip }
  end

  def on_branch?
    at_path { git('branch', '-a') }.split(/\n/).grep(/\*/).to_s.gsub('*', '').strip
  end

  def tags
    at_path { git('tag', '-l') }.split(/\n/).map { |line| line.strip }
  end

  def set_excludes
    at_path { open('.git/info/exclude', 'w') { |f| @resource.value(:excludes).each { |ex| f.write(ex + "\n") }}}
  end

  def get_revision(rev)
    if !working_copy_exists?
      create
    end
    at_path do
      git('fetch', 'origin')
      git('fetch', '--tags', 'origin')
    end
    current = at_path { git('rev-parse', rev).strip }
    if @resource.value(:revision)
      if local_branch_revision?
        canonical = at_path { git('rev-parse', @resource.value(:revision)).strip }
      elsif remote_branch_revision?
        canonical = at_path { git('rev-parse', 'origin/' + @resource.value(:revision)).strip }
      end
        current = @resource.value(:revision) if current == canonical
    end
    return current
  end

  def update_owner_and_excludes
    if @resource.value(:owner) or @resource.value(:group)
      set_ownership
    end
    if @resource.value(:excludes)
      set_excludes
    end
  end
end
