begin
  require 'puppet'
rescue LoadError
  #nothing to see here
else
  desc "Generate the Pcore model that represents the AST for the Puppet Language"
  task :gen_pcore_ast do
    Puppet::Pops.generate_ast
  end

  module Puppet::Pops
    def self.generate_ast
      Puppet.initialize_settings
      env = Puppet.lookup(:environments).get(Puppet[:environment])
      loaders = Loaders.new(env)
      ast_pp = Pathname(__FILE__).parent.parent + 'lib/puppet/pops/model/ast.pp'
      Puppet.override(:current_environment => env, :loaders => loaders) do
        ast_factory = Parser::Parser.new.parse_file(ast_pp.expand_path.to_s)
        ast_model = Types::TypeParser.singleton.interpret(
          ast_factory.model.body, Loader::PredefinedLoader.new(loaders.find_loader(nil), 'TypeSet loader'))

        ruby = Types::RubyGenerator.new.module_definition_from_typeset(ast_model)

        # Replace ref() constructs to known Pcore types with directly initialized types. ref() cannot be used
        # since it requires a parser (chicken-and-egg problem)
        ruby.gsub!(/^module Parser\nmodule Locator\n.*\nend\nend\nmodule Model\n/m, "module Model\n")

        # Remove generated RubyMethod annotations. The ruby methods are there now, no need to also have
        # the annotations present.
        ruby.gsub!(/^\s+'annotations' => \{\n\s+ref\('RubyMethod'\) => \{\n.*\n\s+\}\n\s+\},\n/, '')

        ruby.gsub!(/ref\('([A-Za-z]+)'\)/, 'Types::P\1Type::DEFAULT')
        ruby.gsub!(/ref\('Optional\[([0-9A-Za-z_]+)\]'\)/, 'Types::POptionalType.new(Types::P\1Type::DEFAULT)')
        ruby.gsub!(/ref\('Array\[([0-9A-Za-z_]+)\]'\)/, 'Types::PArrayType.new(Types::P\1Type::DEFAULT)')
        ruby.gsub!(/ref\('Optional\[Array\[([0-9A-Za-z_]+)\]\]'\)/,
            'Types::POptionalType.new(Types::PArrayType.new(Types::P\1Type::DEFAULT))')
        ruby.gsub!(/ref\('Enum(\[[^\]]+\])'\)/) do |match|
          params = $1
          params.gsub!(/\\'/, '\'')
          "Types::PEnumType.new(#{params})"
        end

        # Replace ref() constructs with references to _pcore_type of the types in the module namespace
        ruby.gsub!(/ref\('Puppet::AST::Locator'\)/, 'Parser::Locator::Locator19._pcore_type')
        ruby.gsub!(/ref\('Puppet::AST::([0-9A-Za-z_]+)'\)/, '\1._pcore_type')
        ruby.gsub!(/ref\('Optional\[Puppet::AST::([0-9A-Za-z_]+)\]'\)/, 'Types::POptionalType.new(\1._pcore_type)')
        ruby.gsub!(/ref\('Array\[Puppet::AST::([0-9A-Za-z_]+)\]'\)/, 'Types::PArrayType.new(\1._pcore_type)')
        ruby.gsub!(/ref\('Array\[Puppet::AST::([0-9A-Za-z_]+), 1, default\]'\)/,
            'Types::PArrayType.new(\1._pcore_type, Types::PCollectionType::NOT_EMPTY_SIZE)')

        # Remove the generated ref() method. It's not needed by this model
        ruby.gsub!(/  def self\.ref\(type_string\)\n.*\n  end\n\n/, '')

        # Add Program#current method for backward compatibility
        ruby.gsub!(/(attr_reader :body\n  attr_reader :definitions\n  attr_reader :locator)/, "\\1\n\n  def current\n    self\n  end")

        # Replace the generated registration with a registration that uses the static loader. This will
        # become part of the Puppet bootstrap code and there will be no other loader until we have a
        # parser.
        ruby.gsub!(/^Puppet::Pops::Pcore.register_implementations\((\[[^\]]+\])\)/, <<-RUBY)

module Model
@@pcore_ast_initialized = false
def self.register_pcore_types
  return if @@pcore_ast_initialized
  @@pcore_ast_initialized = true
  all_types = \\1

  # Create and register a TypeSet that corresponds to all types in the AST model
  types_map = {}
  all_types.each do |type|
    types_map[type._pcore_type.simple_name] = type._pcore_type
  end
  type_set = Types::PTypeSetType.new({
    'name' => 'Puppet::AST',
    'pcore_version' => '1.0.0',
    'types' => types_map
  })
  loc = Puppet::Util.path_to_uri("\#{__FILE__}")
  Loaders.static_loader.set_entry(Loader::TypedName.new(:type, 'puppet::ast', Pcore::RUNTIME_NAME_AUTHORITY), type_set, URI("\#{loc}?line=1"))
  Loaders.register_static_implementations(all_types)
end
end
RUBY
        ast_rb = Pathname(__FILE__).parent.parent + 'lib/puppet/pops/model/ast.rb'
        File.open(ast_rb.to_s, 'w') { |f| f.write(ruby) }
      end
    end
  end
end
