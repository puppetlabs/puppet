# Shared contexts for testing against all supported checksum types.
#
# These helpers define nested rspec example groups to test code against all our
# supported checksum types. Example groups that need to be run against all
# types should use the `with_checksum_types` helper which will
# create a new example group for each types and will run the given block
# in each example group.

CHECKSUM_PLAINTEXT = "1\r\n"*4000
CHECKSUM_TYPES_TO_TRY = [
  ['md5', 'a7a169ac84bb863b30484d0aa03139c1'],
  ['md5lite', '22b4182363e81b326e98231fde616782'],
  ['sha256', '47fcae62967db2fb5cba2fc0d9cf3e6767035d763d825ecda535a7b1928b9746'],
  ['sha256lite', 'fd50217a2b0286ba25121bf2297bbe6c197933992de67e4e568f19861444ecf8'],
  ['sha224', '6894cd976b60b2caa825bc699b54f715853659f0243f67cda4dd7ac4'],
  ['sha384', 'afc3d952fe1a4d3aa083d438ea464f6e7456c048d34ff554340721b463b38547e5ee7c964513dfba0d65dd91ac97deb5'],
  ['sha512', 'a953dcd95824cfa2a555651585d3980b1091a740a785d52ee5e72a55c9038242433e55026758636b0a29d0e5f9e77f24bc888ea5d5e01ab36d2bbcb3d3163859']
]

CHECKSUM_STAT_TIME = Time.now
TIME_TYPES_TO_TRY = [
  ['ctime', "#{CHECKSUM_STAT_TIME}"],
  ['mtime', "#{CHECKSUM_STAT_TIME}"]
]

shared_context('with supported checksum types') do
  def self.with_checksum_types(path, file, &block)
    def checksum_valid(checksum_type, expected_checksum, actual_checksum_signature)
      case checksum_type
      when 'mtime', 'ctime'
        expect(DateTime.parse(actual_checksum_signature)).to be >= DateTime.parse(expected_checksum)
      else
        expect(actual_checksum_signature).to eq("{#{checksum_type}}#{expected_checksum}")
      end
    end

    def expect_correct_checksum(meta, checksum_type, checksum, type)
      expect(meta).to_not be_nil
      expect(meta).to be_instance_of(type)
      expect(meta.checksum_type).to eq(checksum_type)
      expect(checksum_valid(checksum_type, checksum, meta.checksum)).to be_truthy
    end

    (CHECKSUM_TYPES_TO_TRY + TIME_TYPES_TO_TRY).each do |checksum_type, checksum|
      describe("when checksum_type is #{checksum_type}") do
        let(:checksum_type) { checksum_type }
        let(:plaintext) { CHECKSUM_PLAINTEXT }
        let(:checksum) { checksum }
        let(:env_path) { tmpfile(path) }
        let(:checksum_file) { File.join(env_path, file) }

        def digest(content)
          Puppet::Util::Checksums.send(checksum_type, content)
        end

        before(:each) do
          FileUtils.mkdir_p(File.dirname(checksum_file))
          File.open(checksum_file, "wb") { |f| f.write plaintext }
        end

        instance_eval(&block)
      end
    end
  end
end
