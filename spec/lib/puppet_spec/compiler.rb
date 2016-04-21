module PuppetSpec::Compiler
  module_function

  def compile_to_catalog(string, node = Puppet::Node.new('test'))
    Puppet[:code] = string
    # see lib/puppet/indirector/catalog/compiler.rb#filter
    Puppet::Parser::Compiler.compile(node).filter { |r| r.virtual? }
  end

  def compile_to_ral(manifest, node = Puppet::Node.new('test'))
    catalog = compile_to_catalog(manifest, node)
    ral = catalog.to_ral
    ral.finalize
    ral
  end

  def compile_to_relationship_graph(manifest, prioritizer = Puppet::Graph::SequentialPrioritizer.new)
    ral = compile_to_ral(manifest)
    graph = Puppet::Graph::RelationshipGraph.new(prioritizer)
    graph.populate_from(ral)
    graph
  end

  def apply_compiled_manifest(manifest, prioritizer = Puppet::Graph::SequentialPrioritizer.new)
    catalog = compile_to_ral(manifest)
    if block_given?
      catalog.resources.each { |res| yield res }
    end
    transaction = Puppet::Transaction.new(catalog,
                                         Puppet::Transaction::Report.new("apply"),
                                         prioritizer)
    transaction.evaluate
    transaction.report.finalize_report

    transaction
  end

  def apply_with_error_check(manifest)
    apply_compiled_manifest(manifest) do |res|
      res.expects(:err).never
    end
  end

  def order_resources_traversed_in(relationships)
    order_seen = []
    relationships.traverse { |resource| order_seen << resource.ref }
    order_seen
  end

  def collect_notices(code, node = Puppet::Node.new('foonode'))
    Puppet[:code] = code
    compiler = Puppet::Parser::Compiler.new(node)
    logs = []
    Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
      yield(compiler)
    end
    logs = logs.select { |log| log.level == :notice }.map { |log| log.message }
    logs
  end

  def eval_and_collect_notices(code, node = Puppet::Node.new('foonode'))
    collect_notices(code, node) do |compiler|
      if block_given?
        compiler.compile do |catalog|
          yield(compiler.topscope, catalog)
          catalog
        end
      else
        compiler.compile
      end
    end
  end
end
