# Shared contexts for testing against all supported digest algorithms.
#
# These helpers define nested rspec example groups to test code against all our
# supported digest algorithms. Example groups that need to be run against all
# algorithms should use the `with_digest_algorithms` helper which will
# create a new example group for each algorithm and will run the given block
# in each example group.
#
# For each algorithm a shared context is defined for the given algorithm that
# has precomputed checksum values and paths. These contexts are included
# automatically based on the rspec metadata selected with
# `with_digest_algorithms`.

DIGEST_ALGORITHMS_TO_TRY = ['md5', 'sha256', 'sha384', 'sha512', 'sha224']

shared_context('with supported digest algorithms', :uses_checksums => true) do

  def self.with_digest_algorithms(&block)
    DIGEST_ALGORITHMS_TO_TRY.each do |digest_algorithm|
      describe("when digest_algorithm is #{digest_algorithm}", :digest_algorithm => digest_algorithm) do
        instance_eval(&block)
      end
    end
  end
end

shared_context("when digest_algorithm is set to sha256", :digest_algorithm => 'sha256') do
  before { Puppet[:digest_algorithm] = 'sha256' }
  after { Puppet[:digest_algorithm] = nil }

  let(:digest_algorithm) { 'sha256' }

  let(:plaintext) { "my\r\ncontents" }
  let(:checksum) { '409a11465ed0938227128b1756c677a8480a8b84814f1963853775e15a74d4b4' }
  let(:bucket_dir) { '4/0/9/a/1/1/4/6/409a11465ed0938227128b1756c677a8480a8b84814f1963853775e15a74d4b4' }

  def digest(content)
    Puppet::Util::Checksums.sha256(content)
  end
end

shared_context("when digest_algorithm is set to md5", :digest_algorithm => 'md5') do
  before { Puppet[:digest_algorithm] = 'md5' }
  after { Puppet[:digest_algorithm] = nil }

  let(:digest_algorithm) { 'md5' }

  let(:plaintext) { "my\r\ncontents" }
  let(:checksum) { 'f0d7d4e480ad698ed56aeec8b6bd6dea' }
  let(:bucket_dir) { 'f/0/d/7/d/4/e/4/f0d7d4e480ad698ed56aeec8b6bd6dea' }

  def digest(content)
    Puppet::Util::Checksums.md5(content)
  end
end

shared_context("when digest_algorithm is set to sha512", :digest_algorithm => 'sha512') do
  before { Puppet[:digest_algorithm] = 'sha512' }
  after { Puppet[:digest_algorithm] = nil }

  let(:digest_algorithm) { 'sha512' }

  let(:plaintext) { "my\r\ncontents" }
  let(:checksum) { 'ed9b62ae313c8e4e3e6a96f937101e85f8f8af8d51dea7772177244087e5d6152778605ad6bdb42886ff1436abaec4fa44acbfe171fda755959b52b0e4e015d4' }
  let(:bucket_dir) { 'e/d/9/b/6/2/a/e/ed9b62ae313c8e4e3e6a96f937101e85f8f8af8d51dea7772177244087e5d6152778605ad6bdb42886ff1436abaec4fa44acbfe171fda755959b52b0e4e015d4' }

  def digest(content)
    Puppet::Util::Checksums.sha512(content)
  end
end

shared_context("when digest_algorithm is set to sha384", :digest_algorithm => 'sha384') do
  before { Puppet[:digest_algorithm] = 'sha384' }
  after { Puppet[:digest_algorithm] = nil }

  let(:digest_algorithm) { 'sha384' }

  let(:plaintext) { "my\r\ncontents" }
  let(:checksum) { 'f40debfec135e4f2b9fb92110c53aadb8e9bda28bb05f09901480fd70126fe3b70f9f074ce6182ec8184eb1bcabe4440' }
  let(:bucket_dir) { 'f/4/0/d/e/b/f/e/f40debfec135e4f2b9fb92110c53aadb8e9bda28bb05f09901480fd70126fe3b70f9f074ce6182ec8184eb1bcabe4440' }

  def digest(content)
    Puppet::Util::Checksums.sha384(content)
  end
end

shared_context("when digest_algorithm is set to sha224", :digest_algorithm => 'sha224') do
  before { Puppet[:digest_algorithm] = 'sha224' }
  after { Puppet[:digest_algorithm] = nil }

  let(:digest_algorithm) { 'sha224' }

  let(:plaintext) { "my\r\ncontents" }
  let(:checksum) { 'b8c05079b24c37a0e03f03e611167a3ea24455db3ad638a3a0c7e9cb' }
  let(:bucket_dir) { 'b/8/c/0/5/0/7/9/b8c05079b24c37a0e03f03e611167a3ea24455db3ad638a3a0c7e9cb' }

  def digest(content)
    Puppet::Util::Checksums.sha224(content)
  end
end
