require 'spec_helper'

describe "Puppet::Util::Windows::Process", :if => Puppet::Util::Platform.windows?  do
  describe "as an admin" do
    it "should have the SeCreateSymbolicLinkPrivilege necessary to create symlinks" do
      # this is a bit of a lame duck test since it requires running user to be admin
      # a better integration test would create a new user with the privilege and verify
      expect(Puppet::Util::Windows::User).to be_admin
      expect(Puppet::Util::Windows::Process.process_privilege_symlink?).to be_truthy
    end

    it "should be able to lookup a standard Windows process privilege" do
      Puppet::Util::Windows::Process.lookup_privilege_value('SeShutdownPrivilege') do |luid|
        expect(luid).not_to be_nil
        expect(luid).to be_instance_of(Puppet::Util::Windows::Process::LUID)
      end
    end

    it "should raise an error for an unknown privilege name" do
      expect { Puppet::Util::Windows::Process.lookup_privilege_value('foo') }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(1313) # ERROR_NO_SUCH_PRIVILEGE
      end
    end
  end

  describe "when reading environment variables" do
    it "will ignore only keys or values with corrupt byte sequences" do
      env_vars = {}

      # Create a UTF-16LE version of the below null separated environment string
      # "a=b\x00c=d\x00e=\xDD\xDD\x00f=g\x00\x00"
      env_var_block =
        "a=b\x00".encode(Encoding::UTF_16LE) +
        "c=d\x00".encode(Encoding::UTF_16LE) +
        'e='.encode(Encoding::UTF_16LE) + "\xDD\xDD".force_encoding(Encoding::UTF_16LE) + "\x00".encode(Encoding::UTF_16LE) +
        "f=g\x00\x00".encode(Encoding::UTF_16LE)

      env_var_block_bytes = env_var_block.bytes.to_a

      FFI::MemoryPointer.new(:byte, env_var_block_bytes.count) do |ptr|
        # uchar here is synonymous with byte
        ptr.put_array_of_uchar(0, env_var_block_bytes)

        # stub the block of memory that the Win32 API would typically return via pointer
        allow(Puppet::Util::Windows::Process).to receive(:GetEnvironmentStringsW).and_return(ptr)
        # stub out the real API call to free memory, else process crashes
        allow(Puppet::Util::Windows::Process).to receive(:FreeEnvironmentStringsW)

        env_vars = Puppet::Util::Windows::Process.get_environment_strings
      end

      # based on corrupted memory, the e=\xDD\xDD should have been removed from the set
      expect(env_vars).to eq({'a' => 'b', 'c' => 'd', 'f' => 'g'})

      # and Puppet should emit a warning about it
      expect(@logs.last.level).to eq(:warning)
      expect(@logs.last.message).to eq("Discarding environment variable e=\uFFFD which contains invalid bytes")
    end
  end

  describe "when setting environment variables" do
    let(:name) { SecureRandom.uuid }

    around :each do |example|
      begin
        example.run
      ensure
        Puppet::Util::Windows::Process.set_environment_variable(name, nil)
      end
    end

    it "sets environment variables containing '='" do
      value = 'foo=bar'
      Puppet::Util::Windows::Process.set_environment_variable(name, value)
      env = Puppet::Util::Windows::Process.get_environment_strings

      expect(env[name]).to eq(value)
    end

    it "sets environment variables contains spaces" do
      Puppet::Util::Windows::Process.set_environment_variable(name, '')
      env = Puppet::Util::Windows::Process.get_environment_strings

      expect(env[name]).to eq('')
    end

    it "sets environment variables containing UTF-8" do
      rune_utf8 = "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7"
      Puppet::Util::Windows::Process.set_environment_variable(name, rune_utf8)
      env = Puppet::Util::Windows::Process.get_environment_strings

      expect(env[name]).to eq(rune_utf8)
    end
  end
end
