#! /usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:file).attrclass(:mode) do
  include PuppetSpec::Files

  let(:path) { tmpfile('mode_spec') }
  let(:resource) { Puppet::Type.type(:file).new :path => path, :mode => '0644' }
  let(:mode) { resource.property(:mode) }

  describe "#validate" do
    it "should reject non-string values" do
      expect {
        mode.value = 0755
      }.to raise_error(Puppet::Error, /The file mode specification must be a string, not 'Fixnum'/)
    end

    it "should accept values specified as octal numbers in strings" do
      expect { mode.value = '0755' }.not_to raise_error
    end

    it "should accept valid symbolic strings" do
      expect { mode.value = 'g+w,u-x' }.not_to raise_error
    end

    it "should not accept strings other than octal numbers" do
      expect do
        mode.value = 'readable please!'
      end.to raise_error(Puppet::Error, /The file mode specification is invalid/)
    end
  end

  describe "#munge" do
    # This is sort of a redundant test, but its spec is important.
    it "should return the value as a string" do
      expect(mode.munge('0644')).to be_a(String)
    end

    it "should accept strings as arguments" do
      expect(mode.munge('0644')).to eq('644')
    end

    it "should accept symbolic strings as arguments and return them intact" do
      expect(mode.munge('u=rw,go=r')).to eq('u=rw,go=r')
    end

    it "should accept integers are arguments" do
      expect(mode.munge(0644)).to eq('644')
    end
  end

  describe "#dirmask" do
    before :each do
      Dir.mkdir(path)
    end

    it "should add execute bits corresponding to read bits for directories" do
      expect(mode.dirmask('0644')).to eq('755')
    end

    it "should not add an execute bit when there is no read bit" do
      expect(mode.dirmask('0600')).to eq('700')
    end

    it "should not add execute bits for files that aren't directories" do
      resource[:path] = tmpfile('other_file')
      expect(mode.dirmask('0644')).to eq('0644')
    end
  end

  describe "#insync?" do
    it "should return true if the mode is correct" do
      FileUtils.touch(path)

      expect(mode).to be_insync('644')
    end

    it "should return false if the mode is incorrect" do
      FileUtils.touch(path)

      expect(mode).to_not be_insync('755')
    end

    it "should return true if the file is a link and we are managing links", :if => Puppet.features.manages_symlinks? do
      Puppet::FileSystem.symlink('anything', path)

      expect(mode).to be_insync('644')
    end

    describe "with a symbolic mode" do
      let(:resource_sym) { Puppet::Type.type(:file).new :path => path, :mode => 'u+w,g-w' }
      let(:mode_sym) { resource_sym.property(:mode) }

      it "should return true if the mode matches, regardless of other bits" do
        FileUtils.touch(path)

        expect(mode_sym).to be_insync('644')
      end

      it "should return false if the mode requires 0's where there are 1's" do
        FileUtils.touch(path)

        expect(mode_sym).to_not be_insync('624')
      end

      it "should return false if the mode requires 1's where there are 0's" do
        FileUtils.touch(path)

        expect(mode_sym).to_not be_insync('044')
      end
    end
  end

  describe "#retrieve" do
    it "should return absent if the resource doesn't exist" do
      resource[:path] = File.expand_path("/does/not/exist")
      expect(mode.retrieve).to eq(:absent)
    end

    it "should retrieve the directory mode from the provider" do
      Dir.mkdir(path)

      mode.expects(:dirmask).with('644').returns '755'
      resource.provider.expects(:mode).returns '755'

      expect(mode.retrieve).to eq('755')
    end

    it "should retrieve the file mode from the provider" do
      FileUtils.touch(path)

      mode.expects(:dirmask).with('644').returns '644'
      resource.provider.expects(:mode).returns '644'

      expect(mode.retrieve).to eq('644')
    end
  end

  describe '#should_to_s' do
    describe 'with a 3-digit mode' do
      it 'returns a 4-digit mode with a leading zero' do
        expect(mode.should_to_s('755')).to eq('0755')
      end
    end

    describe 'with a 4-digit mode' do
      it 'returns the 4-digit mode when the first digit is a zero' do
        expect(mode.should_to_s('0755')).to eq('0755')
      end

      it 'returns the 4-digit mode when the first digit is not a zero' do
        expect(mode.should_to_s('1755')).to eq('1755')
      end
    end
  end

  describe '#is_to_s' do
    describe 'with a 3-digit mode' do
      it 'returns a 4-digit mode with a leading zero' do
        expect(mode.is_to_s('755')).to eq('0755')
      end
    end

    describe 'with a 4-digit mode' do
      it 'returns the 4-digit mode when the first digit is a zero' do
        expect(mode.is_to_s('0755')).to eq('0755')
      end

      it 'returns the 4-digit mode when the first digit is not a zero' do
        expect(mode.is_to_s('1755')).to eq('1755')
      end
    end

    describe 'when passed :absent' do
      it 'returns :absent' do
        expect(mode.is_to_s(:absent)).to eq(:absent)
      end
    end
  end

  describe "#sync with a symbolic mode" do
    let(:resource_sym) { Puppet::Type.type(:file).new :path => path, :mode => 'u+w,g-w' }
    let(:mode_sym) { resource_sym.property(:mode) }

    before { FileUtils.touch(path) }

    it "changes only the requested bits" do
      # lower nibble must be set to 4 for the sake of passing on Windows
      Puppet::FileSystem.chmod(0464, path)

      mode_sym.sync
      stat = Puppet::FileSystem.stat(path)
      expect((stat.mode & 0777).to_s(8)).to eq("644")
    end
  end

  describe '#sync with a symbolic mode of +X for a file' do
    let(:resource_sym) { Puppet::Type.type(:file).new :path => path, :mode => 'g+wX' }
    let(:mode_sym) { resource_sym.property(:mode) }

    before { FileUtils.touch(path) }

    it 'does not change executable bit if no executable bit is set' do
      Puppet::FileSystem.chmod(0644, path)

      mode_sym.sync

      stat = Puppet::FileSystem.stat(path)
      expect((stat.mode & 0777).to_s(8)).to eq('664')
    end

    it 'does change executable bit if an executable bit is set' do
      Puppet::FileSystem.chmod(0744, path)

      mode_sym.sync

      stat = Puppet::FileSystem.stat(path)
      expect((stat.mode & 0777).to_s(8)).to eq('774')
    end
  end
end
