module PuppetSpec::Compiler
  def compile_to_catalog(string, node = Puppet::Node.new('foonode'))
    Puppet[:code] = string
    Puppet::Parser::Compiler.compile(node)
  end

  def apply_compiled_manifest(manifest)
    catalog = compile_to_catalog(manifest)
    ral = catalog.to_ral
    ral.finalize

    transaction = Puppet::Transaction.new(ral)
    transaction.evaluate
    transaction.report.finalize_report

    transaction
  end
end
