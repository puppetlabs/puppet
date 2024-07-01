require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Tar::Gnu, unless: Puppet::Util::Platform.windows? do
  let(:sourcedir)  { '/space path/the/src/dir' }
  let(:sourcefile) { '/space path/the/module.tar.gz' }
  let(:destdir)    { '/space path/the/dest/dir' }
  let(:destfile)   { '/space path/the/dest/fi le.tar.gz' }

  let(:safe_sourcedir)  { '/space\ path/the/src/dir' }
  let(:safe_sourcefile) { '/space\ path/the/module.tar.gz' }
  let(:safe_destdir)    { '/space\ path/the/dest/dir' }
  let(:safe_destfile)   { 'fi\ le.tar.gz' }

  it "unpacks a tar file" do
    expect(Puppet::Util::Execution).to receive(:execute).with("gzip -dc #{safe_sourcefile} | tar --extract --no-same-owner --directory #{safe_destdir} --file -")
    expect(Puppet::Util::Execution).to receive(:execute).with(['find', destdir, '-type', 'd', '-exec', 'chmod', '755', '{}', '+'])
    expect(Puppet::Util::Execution).to receive(:execute).with(['find', destdir, '-type', 'f', '-exec', 'chmod', 'u+rw,g+r,a-st', '{}', '+'])
    expect(Puppet::Util::Execution).to receive(:execute).with(['chown', '-R', '<owner:group>', destdir])
    subject.unpack(sourcefile, destdir, '<owner:group>')
  end

  it "packs a tar file" do
    expect(Puppet::Util::Execution).to receive(:execute).with("tar cf - #{safe_sourcedir} | gzip -c > #{safe_destfile}")
    subject.pack(sourcedir, destfile)
  end
end
