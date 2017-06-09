require 'spec_helper'

describe Puppet::FileSystem::Uniquefile do

  describe "#open_tmp on Windows", :if => Puppet.features.microsoft_windows? do

    describe "with UTF8 characters" do
      include PuppetSpec::Files

      let(:rune_utf8) { "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7" }
      let(:temp_rune_utf8) { tmpdir(rune_utf8) }

      it "should use UTF8 characters in TMP,TEMP,TMPDIR environment variable" do
        # Set the temporary environment variables to the UTF8 temp path
        Puppet::Util::Windows::Process.set_environment_variable('TMPDIR', temp_rune_utf8)
        Puppet::Util::Windows::Process.set_environment_variable('TMP', temp_rune_utf8)
        Puppet::Util::Windows::Process.set_environment_variable('TEMP', temp_rune_utf8)

        # Create a unique file
        filename = Puppet::FileSystem::Uniquefile.open_tmp('foo') do |file|
          File.dirname(file.path)
        end

        expect(filename).to eq(temp_rune_utf8)
      end
    end
  end

end
