require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'

# A Backend class that doesn't implement the needed API
class Puppet::Pops::Binder::Hiera2::Bad_backend
end

describe 'The hiera2 config' do

  include PuppetSpec::Pops

  let(:acceptor) {  Puppet::Pops::Validation::Acceptor.new() }
  let(:diag) {  Puppet::Pops::Binder::Hiera2::DiagnosticProducer.new(acceptor) }

  def config_dir(config_name)
    File.dirname(my_fixture("#{config_name}/hiera.yaml"))
  end

  def test_config_issue(config_name, issue)
    Puppet::Pops::Binder::Hiera2::Config.new(config_dir(config_name), diag)
    acceptor.should have_issue(issue)
  end

  context 'using hiera.yaml version 3' do
    it 'should load and validate OK configuration' do
      Puppet::Pops::Binder::Hiera2::Config.new(config_dir('ok'), diag)
      acceptor.errors_or_warnings?.should() == false
    end

    it 'should load and validate OK configuration with only a single category' do
      Puppet::Pops::Binder::Hiera2::Config.new(config_dir('ok_defaults'), diag)
      acceptor.errors_or_warnings?.should() == false
    end

    it 'should load and validate OK configuration with only a list of paths' do
      Puppet::Pops::Binder::Hiera2::Config.new(config_dir('ok_simple'), diag)
      acceptor.errors_or_warnings?.should() == false
    end

    it 'should report missing config file' do
      Puppet::Pops::Binder::Hiera2::Config.new(File.dirname(my_fixture('missing/foo.txt')), diag)
      acceptor.should have_issue(Puppet::Pops::Binder::Hiera2::Issues::CONFIG_FILE_NOT_FOUND)
    end

    it 'should report when config is not a hash' do
      test_config_issue('not_a_hash', Puppet::Pops::Binder::Hiera2::Issues::CONFIG_IS_NOT_HASH)
    end

    it 'should report when config has syntax problems' do
      if RUBY_VERSION.start_with?("1.8")
        # Yes, it is a lobotomy or 2 short of a full brain...
        # if a hash key is not in quotes it continues on the next line and gobbles what is there instead
        # of reporting an error
        test_config_issue('bad_syntax', Puppet::Pops::Binder::Hiera2::Issues::MISSING_HIERARCHY)
      else
        test_config_issue('bad_syntax', Puppet::Pops::Binder::Hiera2::Issues::CONFIG_FILE_SYNTAX_ERROR)
      end
    end

    it 'should report when config has no hierarchy defined' do
      test_config_issue('no_hierarchy', Puppet::Pops::Binder::Hiera2::Issues::MISSING_HIERARCHY)
    end

    it 'should report when config has no backends defined' do
      test_config_issue('no_backends', Puppet::Pops::Binder::Hiera2::Issues::MISSING_BACKENDS)
    end

    it 'should report when config hierarchy is malformed' do
      test_config_issue('malformed_hierarchy', Puppet::Pops::Binder::Hiera2::Issues::HIERARCHY_WRONG_TYPE)
    end

    it 'should report when config hierarchy entry has no category' do
      test_config_issue('missing_category', Puppet::Pops::Binder::Hiera2::Issues::HIERARCHY_ENTRY_MISSING_ATTRIBUTE)
    end

    it 'should report when config hierarchy entry has unknown attribute category' do
      test_config_issue('unknown_attribute', Puppet::Pops::Binder::Hiera2::Issues::UNKNOWN_CATEGORY_ATTRIBUTE)
    end

    it 'should report when config hierarchy commmon category has a value' do
      test_config_issue('common_with_value', Puppet::Pops::Binder::Hiera2::Issues::ILLEGAL_VALUE_FOR_COMMON)
    end

    it 'should report when both path and paths are used' do
      test_config_issue('path_and_paths', Puppet::Pops::Binder::Hiera2::Issues::PATH_PATHS_EXCLUSIVE)
    end

    it 'should report when path is not a string' do
      test_config_issue('path_not_string', Puppet::Pops::Binder::Hiera2::Issues::CATEGORY_ATTR_WRONG_TYPE)
    end

    it 'should report when path is empty' do
      test_config_issue('path_empty', Puppet::Pops::Binder::Hiera2::Issues::CATEGORY_ATTR_EMPTY)
    end

    it 'should report when an entry in paths is empty' do
      test_config_issue('paths_empty', Puppet::Pops::Binder::Hiera2::Issues::CATEGORY_ATTR_ARRAY_ENTRY_EMPTY)
    end

    it 'should report when both paths is not a Array[string]' do
      test_config_issue('paths_not_arr_string', Puppet::Pops::Binder::Hiera2::Issues::CATEGORY_ATTR_WRONG_TYPE)
    end

    it "should report when 'value' is not a string" do
      test_config_issue('value_not_string', Puppet::Pops::Binder::Hiera2::Issues::CATEGORY_ATTR_WRONG_TYPE)
    end

    it "should report when 'datadir' is not a string" do
      test_config_issue('datadir_not_string', Puppet::Pops::Binder::Hiera2::Issues::CATEGORY_ATTR_WRONG_TYPE)
    end
  end
end
