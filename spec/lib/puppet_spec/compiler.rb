module PuppetSpec::Compiler
  def compile_to_catalog(string, node = Puppet::Node.new('foonode'))
    Puppet[:code] = string
    Puppet::Parser::Compiler.compile(node)
  end

  def compile_to_ral(manifest)
    catalog = compile_to_catalog(manifest)
    ral = catalog.to_ral
    ral.finalize
    ral
  end

  def compile_to_relationship_graph(manifest)
    compile_to_ral(manifest).relationship_graph
  end

  def apply_compiled_manifest(manifest)
    transaction = Puppet::Transaction.new(compile_to_ral(manifest))
    transaction.evaluate
    transaction.report.finalize_report

    transaction
  end
end
