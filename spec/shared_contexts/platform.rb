# Contexts for stubbing platforms

shared_context "windows", :as_platform => :windows do
  before :each do
    Facter.stubs(:value).with(:operatingsystem).returns 'Windows'
    Puppet.features.stubs(:microsoft_windows?).returns(true)
    Puppet.features.stubs(:posix?).returns(false)
  end

  around do |example|
    file_alt_separator = File::ALT_SEPARATOR
    with_verbose_disabled do
      File::ALT_SEPARATOR = '\\'
    end
    example.run
    with_verbose_disabled do
      File::ALT_SEPARATOR = file_alt_separator
    end
  end
end

shared_context "posix", :as_platform => :posix do
  before :each do
    Puppet.features.stubs(:microsoft_windows?).returns(false)
    Puppet.features.stubs(:posix?).returns(true)
  end

  around do |example|
    file_alt_separator = File::ALT_SEPARATOR
    with_verbose_disabled do
      File::ALT_SEPARATOR = nil
    end
    example.run
    with_verbose_disabled do
      File::ALT_SEPARATOR = file_alt_separator
    end
  end
end
