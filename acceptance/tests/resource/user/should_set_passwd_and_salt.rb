test_name 'C97905: user resource shall set password, salt and iterations' do
  confine :except, :platform => /^eos-/ # See ARISTA-37
  confine :except, :platform => /^cisco_/ # See PUP-5828

  app_type = File.basename(__FILE__, '.*')
  name = "#{app_type}_#{[*('a'..'z'),*('0'..'9')].shuffle[0,8].join}"

  teardown do
    step "delete the user, and group, if any" do
      agents.each do |agent|
        on(agent, puppet("resource user #{name} ensure=absent"), :accept_any_exit_code => true)
        on(agent, puppet("resource group #{name} ensure=absent"), :accept_any_exit_code => true)
      end
    end
  end

  manifest = <<MANIFEST
    user { '#{name}':
      ensure     => 'present',
      iterations => '46948',
      password   => '9690da8dd8f90f6e3fed4f267c86110e29d75e8448efdacdee9bd5cc20f81a563c9e6c6c328694fac80910ba99508cc373525ac592b87fbec0ac1a1e26a51f01873c25f2450aa78e09c8498df0f11fa930c3f655e7aeed6bc61e8475ca84297b3a2273d31974ddd232e872d9b66be82d0246d094d60155c93c6b7a27ba1aa390',
      salt       => '62133b77a7aeecf506ffe99d064b3f8c068344de0a619a573a871f2fd6fe9eaf',
    }
MANIFEST

  step 'apply manifest creating user with password and salt' do
    apply_manifest_on(agents, manifest)
  end

  step 'apply manifest again, to ensure idempotent' do
    apply_manifest_on(agents, manifest)
  end

end
