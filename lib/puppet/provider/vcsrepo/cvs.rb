require File.join(File.dirname(__FILE__), '..', 'vcsrepo')

Puppet::Type.type(:vcsrepo).provide(:cvs, :parent => Puppet::Provider::Vcsrepo) do
  desc "Supports CVS repositories/workspaces"

  commands   :cvs => 'cvs'
  defaultfor :cvs => :exists
  has_features :gzip_compression, :reference_tracking
  
  def create
    if !@resource.value(:source)
      create_repository(@resource.value(:path))
    else
      checkout_repository
    end
  end

  def exists?
    if @resource.value(:source)
      directory = File.join(@resource.value(:path), 'CVS')
    else
      directory = File.join(@resource.value(:path), 'CVSROOT')
    end
    File.directory?(directory)
  end

  def destroy
    FileUtils.rm_rf(@resource.value(:path))
  end

  def revision
    if File.exist?(tag_file)
      contents = File.read(tag_file)
      # Note: Doesn't differentiate between N and T entries
      contents[1..-1]
    else
      'MAIN'
    end
  end

  def revision=(desired)
    at_path do
      cvs('update', '-r', desired, '.')
    end
  end

  private

  def tag_file
    File.join(@resource.value(:path), 'CVS', 'Tag')
  end

  def checkout_repository
    dirname, basename = File.split(@resource.value(:path))
    Dir.chdir(dirname) do
      args = ['-d', @resource.value(:source)]
      if @resource.value(:compression)
        args.push('-z', @resource.value(:compression))
      end
      args.push('checkout', '-d', basename, module_name)
      cvs(*args)
    end
    if @resource.value(:revision)
      self.revision = @resource.value(:revision)
    end
  end

  # When the source:
  # * Starts with ':' (eg, :pserver:...)
  def module_name
    if (source = @resource.value(:source))
      source[0, 1] == ':' ? File.basename(source) : '.'
    end
  end

  def create_repository(path)
    cvs('-d', path, 'init')
  end

end
