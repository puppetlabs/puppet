# Contexts for stubbing platforms
# In a describe or context block, adding :as_platform => :windows or
# :as_platform => :posix will stub the relevant Puppet features, as well as
# the behavior of Ruby's filesystem methods by changing File::ALT_SEPARATOR.

shared_context "windows", :as_platform => :windows do
  before :each do
    Facter.stubs(:value).with(:operatingsystem).returns 'Windows'
    Facter.stubs(:value).with(:osfamily).returns 'windows'
    Puppet.features.stubs(:microsoft_windows?).returns(true)
    Puppet.features.stubs(:posix?).returns(false)
  end

  around do |example|
    file_alt_separator = File::ALT_SEPARATOR
    file_path_separator = File::PATH_SEPARATOR

    # prevent Ruby from warning about changing a constant
    with_verbose_disabled do
      File::ALT_SEPARATOR = '\\'
      File::PATH_SEPARATOR = ';'
    end
    example.run
    with_verbose_disabled do
      File::ALT_SEPARATOR = file_alt_separator
      File::PATH_SEPARATOR = file_path_separator
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
    file_path_separator = File::PATH_SEPARATOR

    # prevent Ruby from warning about changing a constant
    with_verbose_disabled do
      File::ALT_SEPARATOR = nil
      File::PATH_SEPARATOR = ':'
    end
    example.run
    with_verbose_disabled do
      File::ALT_SEPARATOR = file_alt_separator
      File::PATH_SEPARATOR = file_path_separator
    end
  end
end
