require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/pops'
require 'puppet/loaders'

describe 'dependency loader' do
  include PuppetSpec::Files

  let(:static_loader) { Puppet::Pops::Loader::StaticLoader.new() }
  let(:loaders) { Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, [])) }

  describe 'FileBased module loader' do
    it 'load something in global name space raises an error' do
      module_dir = dir_containing('testmodule', {
      'lib' => { 'puppet' => { 'functions' => { 'testmodule' => {
        'foo.rb' => 'Puppet::Functions.create_function("foo") { def foo; end; }'
      }}}}})

      loader = loader_for('testmodule', module_dir)

      expect do
        loader.load_typed(typed_name(:function, 'testmodule::foo')).value
      end.to raise_error(ArgumentError, /produced mis-matched name, expected 'testmodule::foo', got foo/)
    end

    it 'can load something in a qualified name space' do
      module_dir = dir_containing('testmodule', {
      'lib' => { 'puppet' => { 'functions' => { 'testmodule' => {
        'foo.rb' => 'Puppet::Functions.create_function("testmodule::foo") { def foo; end; }'
      }}}}})

      loader = loader_for('testmodule', module_dir)

      function = loader.load_typed(typed_name(:function, 'testmodule::foo')).value

      expect(function.class.name).to eq('testmodule::foo')
      expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
    end

    it 'can load something in a qualified name space more than once' do
      module_dir = dir_containing('testmodule', {
      'lib' => { 'puppet' => { 'functions' => { 'testmodule' => {
        'foo.rb' => 'Puppet::Functions.create_function("testmodule::foo") { def foo; end; }'
      }}}}})

      loader = loader_for('testmodule', module_dir)

      function = loader.load_typed(typed_name(:function, 'testmodule::foo')).value
      expect(function.class.name).to eq('testmodule::foo')
      expect(function.is_a?(Puppet::Functions::Function)).to eq(true)

      function = loader.load_typed(typed_name(:function, 'testmodule::foo')).value
      expect(function.class.name).to eq('testmodule::foo')
      expect(function.is_a?(Puppet::Functions::Function)).to eq(true)
    end

    describe "when parsing files from disk" do

      # First line of Rune version of Rune poem at http://www.columbia.edu/~fdc/utf8/
      # characters chosen since they will not parse on Windows with codepage 437 or 1252
      # Section 3.2.1.3 of Ruby spec guarantees that \u strings are encoded as UTF-8
      let (:node) { Puppet::Node.new('node') }
      let (:rune_utf8) { "\u16A0\u16C7\u16BB" } # ᚠᛇᚻ
      let (:code_utf8) do <<-CODE
Puppet::Functions.create_function('testmodule::foo') {
  def foo
    return \"#{rune_utf8}\"
  end
}
      CODE
      end

      context 'when loading files from disk' do
        it 'should always read files as UTF-8' do
          if Puppet.features.microsoft_windows? && Encoding.default_external == Encoding::UTF_8
            raise 'This test must be run in a codepage other than 65001 to validate behavior'
          end

          module_dir = dir_containing('testmodule', {
          'lib' => { 'puppet' => { 'functions' => { 'testmodule' => {
            'foo.rb' => code_utf8
          }}}}})

          loader = loader_for('testmodule', module_dir)

          function = loader.load_typed(typed_name(:function, 'testmodule::foo')).value
          expect(function.call({})).to eq(rune_utf8)
        end

        it 'currently ignores the UTF-8 BOM (Byte Order Mark) when loading module files' do
          bom = "\uFEFF"

          if Puppet.features.microsoft_windows? && Encoding.default_external == Encoding::UTF_8
            raise 'This test must be run in a codepage other than 65001 to validate behavior'
          end

          module_dir = dir_containing('testmodule', {
          'lib' => { 'puppet' => { 'functions' => { 'testmodule' => {
            'foo.rb' => "#{bom}#{code_utf8}"
          }}}}})

          loader = loader_for('testmodule', module_dir)

          function = loader.load_typed(typed_name(:function, 'testmodule::foo')).value
          expect(function.call({})).to eq(rune_utf8)
        end
      end
    end
  end

  def loader_for(name, dir)
      module_loader = Puppet::Pops::Loader::ModuleLoaders.module_loader_from(static_loader, loaders, name, dir)
      Puppet::Pops::Loader::DependencyLoader.new(static_loader, 'test-dep', [module_loader])
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end
end
