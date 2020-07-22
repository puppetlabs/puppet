require 'spec_helper'
require 'webmock/rspec'

describe "Puppet plugin face" do
  before :each do
    metadata = "[{\"path\":\"/etc/puppetlabs/code\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":0,\"group\":0,\"mode\":420,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-07-10 14:00:00 -0700\"},\"type\":\"directory\",\"destination\":null}]"
    stub_request(:get, %r{/puppet/v3/file_metadatas/(plugins|locales)}).to_return(status: 200, body: metadata, headers: {'Content-Type' => 'application/json'})

    # response retains owner/group/mode due to source_permissions => use
    facts_metadata = "[{\"path\":\"/etc/puppetlabs/code\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":500,\"group\":500,\"mode\":493,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-07-10 14:00:00 -0700\"},\"type\":\"directory\",\"destination\":null}]"
    stub_request(:get, %r{/puppet/v3/file_metadatas/pluginfacts}).to_return(status: 200, body: facts_metadata, headers: {'Content-Type' => 'application/json'})
  end

  it "processes a download request resulting in no changes" do
    # /opt/puppetlabs/puppet/cache/facts.d will be created based on our umask.
    # If the mode on disk is not 0755, then the mode from the metadata response
    # (493 => 0755) will be applied, resulting in "plugins were downloaded"
    # message. Enforce a umask so the results are consistent.
    Puppet::FileSystem.mkpath(Puppet[:pluginfactdest])
    Puppet::FileSystem.chmod(0755, Puppet[:pluginfactdest])

    app = Puppet::Application[:plugin]
    app.command_line.args << 'download'
    expect {
      app.run
    }.to exit_with(0)
      .and output(/No plugins downloaded/).to_stdout
  end

  it "updates the facts.d mode", unless: Puppet::Util::Platform.windows? do
    Puppet::FileSystem.mkpath(Puppet[:pluginfactdest])
    Puppet::FileSystem.chmod(0775, Puppet[:pluginfactdest])

    app = Puppet::Application[:plugin]
    app.command_line.args << 'download'
    expect {
      app.run
    }.to exit_with(0)
     .and output(/Downloaded these plugins: .*facts\.d/).to_stdout
  end
end
