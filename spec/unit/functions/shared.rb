
shared_examples_for 'all iterative functions hash handling' do |func|
  it 'passes a hash entry as an array of the key and value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      {a=>1}.#{func} |$v| { notify { "${v[0]} ${v[1]}": } }
    MANIFEST

    catalog.resource(:notify, "a 1").should_not be_nil
  end
end

shared_examples_for 'all iterative functions argument checks' do |func|

  it 'raises an error when used against an unsupported type' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        3.14.#{func} |$v| {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /must be something enumerable/)
  end

  it 'raises an error when called with any parameters besides a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].#{func}(1) |$v| {  }
      MANIFEST
  end.to raise_error(Puppet::Error, /mis-matched arguments.*expected.*arg count \{2\}.*actual.*arg count \{3\}/m)
  end

  it 'raises an error when called without a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].#{func}()
      MANIFEST
    end.to raise_error(Puppet::Error, /mis-matched arguments.*expected.*arg count \{2\}.*actual.*arg count \{1\}/m)
  end

  it 'raises an error when called with something that is not a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].#{func}(1)
      MANIFEST
    end.to raise_error(Puppet::Error, /mis-matched arguments.*expected.*Callable.*actual(?!Callable\)).*/m)
  end
end
