test_name "PUP-8735: UTF-8 characters are preserved after recursively copying directories" do

  tag 'audit:high', # utf-8 is high impact in general
      'audit:integration' # not package dependent but may want to vary platform by LOCALE/encoding

  # Translation is not supported on these platforms:
  confine :except, :platform => /^eos-/
  confine :except, :platform => /^cisco/
  confine :except, :platform => /^cumulus/
  confine :except, :platform => /^solaris/

  # for file_exists?
  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  # for enable_locale_language
  require 'puppet/acceptance/i18n_utils'
  extend Puppet::Acceptance::I18nUtils

  agents.each do |host|
    filename = "Fișier"
    content = <<-CONTENT
閑けさや
岩にしみいる
蝉の声
    CONTENT

    workdir = host.tmpdir("tmp#{rand(999999).to_i}")
    source_dir = "#{workdir}/Adresář"
    target_dir = "#{workdir}/目录"

    manifest = %Q|
file { ["#{workdir}", "#{source_dir}"]:
  ensure => directory,
}

file { "#{source_dir}/#{filename}":
  ensure  => file,
  content => "#{content}",
}

file { "#{source_dir}/#{filename}_Copy":
  ensure => file,
  source =>  "#{source_dir}/#{filename}",
}

file { "#{target_dir}":
  ensure  => directory,
  source  => "#{source_dir}",
  recurse => remote,
  replace => true,
}|

    step "Ensure the en_US locale is enabled (and skip this test if not)" do
      if enable_locale_language(host, 'en_US').nil?
        skip_test("Host #{host} is missing the en_US locale. Skipping this test.")
      end
    end

    step "Create and recursively copy a directory with UTF-8 filenames and contents" do
      apply_manifest_on(host, manifest, environment: {'LANGUAGE' => 'en_US', 'LANG' => 'en_US'})
    end

    step "Ensure that the files' names and their contents are preserved" do
      ["#{target_dir}/#{filename}", "#{target_dir}/#{filename}_Copy"]. each do |filepath|
        assert(file_exists?(host, filepath), "Expected the UTF-8 directory's files to be recursivly copied, but they were not")
        assert(file_contents(host, filepath) == content, "Expected the contents of the copied UTF-8 files to be preserved, but they were not")
      end
    end
  end
end
