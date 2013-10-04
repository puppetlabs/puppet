
shared_examples_for 'all iterative functions hash handling' do |func|
  it 'passes a hash entry as an array of the key and value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      {a=>1}.#{func} { |$v| notify { "${v[0]} ${v[1]}": } }
    MANIFEST

    catalog.resource(:notify, "a 1").should_not be_nil
  end
end

shared_examples_for 'all iterative functions argument checks' do |func|

  it 'raises an error when defined with more than 1 argument' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].#{func} { |$x, $yikes| }
      MANIFEST
    end.to raise_error(Puppet::Error, /Too few arguments/)
  end

  it 'raises an error when defined with fewer than 1 argument' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].#{func} { || }
      MANIFEST
    end.to raise_error(Puppet::Error, /Too many arguments/)
  end

  it 'raises an error when used against an unsupported type' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        "not correct".#{func} { |$v| }
      MANIFEST
    end.to raise_error(Puppet::Error, /must be an Array or a Hash/)
  end

  it 'raises an error when called with any parameters besides a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].#{func}(1) { |$v| }
      MANIFEST
    end.to raise_error(Puppet::Error, /Wrong number of arguments/)
  end

  it 'raises an error when called without a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].#{func}()
      MANIFEST
    end.to raise_error(Puppet::Error, /Wrong number of arguments/)
  end

  it 'raises an error when called without a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].#{func}(1)
      MANIFEST
    end.to raise_error(Puppet::Error, /must be a parameterized block/)
  end
end
