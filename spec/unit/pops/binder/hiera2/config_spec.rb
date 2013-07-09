require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'

# A Backend class that doesn't implement the needed API
class Puppet::Pops::Binder::Hiera2::Bad_backend
end

describe 'The hiera2 config' do

  include PuppetSpec::Pops

  let(:_Hiera2) {  Puppet::Pops::Binder::Hiera2 }
  let(:_Issues) {  _Hiera2::Issues }

  let(:acceptor) {  Puppet::Pops::Validation::Acceptor.new() }
  let(:diag) {  _Hiera2::DiagnosticProducer.new(acceptor) }

  def config_dir(config_name)
    File.dirname(my_fixture("#{config_name}/hiera_config.yaml"))
  end

  def test_config_issue(config_name, issue)
    _Hiera2::Config.new(config_dir(config_name), diag)
    acceptor.should have_issue(issue)
  end

  it 'should load and validate OK configuration' do
    _Hiera2::Config.new(config_dir('ok'), diag)
    acceptor.errors_or_warnings?.should() == false
  end

  it 'should report missing config file' do
    _Hiera2::Config.new(File.dirname(my_fixture('missing/foo.txt')), diag)
    acceptor.should have_issue(_Issues::CONFIG_FILE_NOT_FOUND)
  end

  it 'should report when config is not a hash' do
    test_config_issue('not_a_hash', _Issues::CONFIG_IS_NOT_HASH)
  end

  it 'should report when config has syntax problems' do
    test_config_issue('bad_syntax', _Issues::CONFIG_FILE_SYNTAX_ERROR)
  end

  it 'should report when config has no hierarchy defined' do
    test_config_issue('no_hierarchy', _Issues::MISSING_HIERARCHY)
  end

  it 'should report when config has no backends defined' do
    test_config_issue('no_backends', _Issues::MISSING_BACKENDS)
  end

  it 'should report when config hierarchy is malformed' do
    test_config_issue('malformed_hierarchy', _Issues::CATEGORY_MUST_BE_TWO_ELEMENT_ARRAY)
  end

  it 'should report when backends cannot be loaded' do
    test_config_issue('missing_backend', _Issues::CANNOT_LOAD_BACKEND)
  end

  it 'should report backends that doesn not respond to needed methods' do
    test_config_issue('not_a_backend', _Issues::NOT_A_BACKEND_CLASS)
  end
end
