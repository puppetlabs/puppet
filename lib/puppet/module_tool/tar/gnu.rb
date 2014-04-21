class Puppet::ModuleTool::Tar::Gnu
  def unpack(sourcefile, destdir, owner)
    sourcefile = File.expand_path(sourcefile)
    destdir = File.expand_path(destdir)

    Dir.chdir(destdir) do
      tarball = Puppet::Util::Execution.execute(['gzip', '-dc', sourcefile])
      Puppet::Util::Execution.execpipe(['tar', 'xof', '-'], true, 'w+') do |pipe|
        pipe.write(tarball)
      end

      Puppet::Util::Execution.execute(['find', destdir] + %w[-type d -exec chmod 755 {} +])
      Puppet::Util::Execution.execute(['find', destdir] + %w[-type f -exec chmod a-wst {} +])
      Puppet::Util::Execution.execute(['chown', '-R', owner, destdir])
    end
  end

  def pack(sourcedir, destfile)
    tarball = Puppet::Util::Execution.execute(['tar', 'cf', '-', sourcedir])
    Puppet::Util::Execution.execpipe(['gzip', '-c'], true, 'w+') do |pipe|
      pipe.write(tarball)
      pipe.close_write
      File.open(destfile, 'w+') do |file|
        file.write(pipe.read)
      end
    end
  end
end
