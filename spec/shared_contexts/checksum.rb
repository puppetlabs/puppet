# Shared contexts for testing against all supported checksum types.
#
# These helpers define nested rspec example groups to test code against all our
# supported checksum types. Example groups that need to be run against all
# types should use the `with_checksum_types` helper which will
# create a new example group for each types and will run the given block
# in each example group.

CHECKSUM_STAT_TIME = Time.now
CHECKSUM_TYPES_TO_TRY = [
  ['md5', 'a7a169ac84bb863b30484d0aa03139c1'],
  ['md5lite', '22b4182363e81b326e98231fde616782'],
  ['sha256', '47fcae62967db2fb5cba2fc0d9cf3e6767035d763d825ecda535a7b1928b9746'],
  ['sha256lite', 'fd50217a2b0286ba25121bf2297bbe6c197933992de67e4e568f19861444ecf8'],
  ['ctime', "#{CHECKSUM_STAT_TIME}"],
  ['mtime', "#{CHECKSUM_STAT_TIME}"]
]

shared_context('with supported checksum types') do

  def self.with_checksum_types(path, file, &block)
    def expect_correct_checksum(meta, checksum_type, checksum, type)
      expect(meta).to_not be_nil
      expect(meta).to be_instance_of(type)
      expect(meta.checksum_type).to eq(checksum_type)
      expect(meta.checksum).to eq("{#{checksum_type}}#{checksum}")
    end

    CHECKSUM_TYPES_TO_TRY.each do |checksum_type, checksum|
      describe("when checksum_type is #{checksum_type}") do
        let(:checksum_type) { checksum_type }
        let(:plaintext) { "1\r\n"*4000 }
        let(:checksum) { checksum }
        let(:env_path) { tmpfile(path) }
        let(:checksum_file) { File.join(env_path, file) }

        before do
          FileUtils.mkdir_p(File.dirname(checksum_file))
          File.open(checksum_file, "wb") { |f| f.write plaintext }
          Puppet::FileSystem.stubs(:stat).returns(stub('stat', :ctime => CHECKSUM_STAT_TIME, :mtime => CHECKSUM_STAT_TIME))
        end

        instance_eval(&block)
      end
    end
  end
end

