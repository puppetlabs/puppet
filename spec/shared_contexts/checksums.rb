# Shared contexts for testing against all supported digest algorithms.
#
# These helpers define nested rspec example groups to test code against all our
# supported digest algorithms. Example groups that need to be run against all
# algorithms should use the `using_checksums_describe` helper which will
# create a new example group for each algorithm and will run the given block
# in each example group.
#
# For each algorithm a shared context is defined for the given algorithm that
# has precomputed checksum values and paths. These contexts are included
# automatically based on the rspec metadata selected with
# `using_checksums_describe`.

DIGEST_ALGORITHMS_TO_TRY = ['md5', 'sha256']

shared_context('with supported digest algorithms', :uses_checksums => true) do

  # Drop-in replacement for the describe class method, which makes an
  # example group containing one copy of the given group for each
  # value of the :digest_algorithm Puppet setting given in
  # DIGEST_ALGORITHMS_TO_TRY.
  def self.using_checksums_describe(*args, &block)
    DIGEST_ALGORITHMS_TO_TRY.each do |algorithm|
      describe("when digest_algorithm is #{algorithm}", :digest_algorithm => algorithm) do
        describe(*args, &block)
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

  let(:not_bucketed_plaintext) { "other stuff" }
  let(:not_bucketed_checksum) { '71e19d6834b179eff0012516fa1397c392d5644a3438644e3f23634095a84974' }
  let(:not_bucketed_bucket_dir) { '7/1/e/1/9/d/6/8/71e19d6834b179eff0012516fa1397c392d5644a3438644e3f23634095a84974' }

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

  let(:not_bucketed_plaintext) { "other stuff" }
  let(:not_bucketed_checksum) { 'c0133c37ea4b55af2ade92e1f1337568' }
  let(:not_bucketed_bucket_dir) { 'c/0/1/3/3/c/3/7/c0133c37ea4b55af2ade92e1f1337568' }

  def digest(content)
    Puppet::Util::Checksums.md5(content)
  end
end
