require 'pathname'

module PuppetSpec::Fixtures
  def fixtures(*rest)
    File.join(PuppetSpec::FIXTURE_DIR, *rest)
  end
  def my_fixture_dir
    callers = caller
    while line = callers.shift do
      next unless found = line.match(%r{/spec/(.*)_spec\.rb:})
      return fixtures(found[1])
    end
    fail "sorry, I couldn't work out your path from the caller stack!"
  end
  def my_fixture(name)
    file = (Pathname(my_fixture_dir) + name).relative_path_from(Pathname.getwd).to_s

    unless File.readable? file then
      fail Puppet::DevError, "fixture '#{name}' for #{my_fixture_dir} is not readable"
    end
    return file
  end
  def my_fixtures(glob = '*', flags = 0)
    pwd   = Pathname.getwd
    files = Pathname.glob(Pathname(my_fixture_dir) + glob, flags).
      map {|f| f.relative_path_from(pwd).to_s }

    unless files.length > 0 then
      fail Puppet::DevError, "fixture '#{glob}' for #{my_fixture_dir} had no files!"
    end

    block_given? and files.each {|file| yield file }
    files
  end
end
