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
    file = File.join(my_fixture_dir, name)
    unless File.readable? file then
      fail Puppet::DevError, "fixture '#{name}' for #{my_fixture_dir} is not readable"
    end
    return file
  end
  def my_fixtures(glob = '*', flags = 0)
    files = Dir.glob(File.join(my_fixture_dir, glob), flags)
    unless files.length > 0 then
      fail Puppet::DevError, "fixture '#{glob}' for #{my_fixture_dir} had no files!"
    end
    block_given? and files.each do |file| yield file end
    files
  end
end
