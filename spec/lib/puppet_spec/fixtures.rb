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

  def pem_content(name)
    File.read(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', name), encoding: 'UTF-8')
  end

  def cert_fixture(name)
    OpenSSL::X509::Certificate.new(pem_content(name))
  end

  def crl_fixture(name)
    OpenSSL::X509::CRL.new(pem_content(name))
  end

  def key_fixture(name)
    OpenSSL::PKey::RSA.new(pem_content(name))
  end

  def ec_key_fixture(name)
    OpenSSL::PKey::EC.new(pem_content(name))
  end

  def request_fixture(name)
    OpenSSL::X509::Request.new(pem_content(name))
  end
end
