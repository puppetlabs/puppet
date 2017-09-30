test_name 'C100559: puppet agent run output with a supported language should be localized' do
  confine :except, :platform => /^eos-/    # translation not supported
  confine :except, :platform => /^cisco_/  # translation not supported
  confine :except, :platform => /^cumulus/ # translation not supported
  confine :except, :platform => /^solaris/ # translation not supported
  confine :except, :platform => /^aix/     # QENG-5283 needed for this to work

  tag 'audit:medium',
      'audit:acceptance'

  def language_name(language)
    on(agent, 'locale -a') do |locale_result|
      ["#{language}.utf8", "#{language}.UTF-8", language].each do |lang|
        return lang if locale_result.stdout =~ /#{lang}/
      end
      # no supported language installed skip test on this machine
      skip_test("test machine is missing #{language} local Skipping")
    end
  end

  language = 'ja_JP'
  agents.each do |agent|
    step("ensure #{language} locale is configured") do
      if agent['platform'] =~ /ubuntu/
        on(agent, 'locale -a') do |locale_result|
          if locale_result.stdout !~ /#{language}/
            on(agent, "locale-gen --lang #{language}")
            language = language_name(language)
          end
        end
      elsif agent['platform'] =~ /debian/
        on(agent, 'locale -a') do |locale_result|
          if locale_result.stdout !~ /#{language}/
            on(agent, "cp /etc/locale.gen /etc/locale.gen.orig ; sed -e 's/# ja_JP.UTF-8/ja_JP.UTF-8/' /etc/locale.gen.orig > /etc/locale.gen")
            on(agent, 'locale-gen')
            language = language_name(language)
          end
        end
      end
    end

    step "Run Puppet apply with language #{language} and check the output" do
      on(agent, puppet("agent -t --server #{master}", 'ENV' => {'LANGUAGE' => language})) do |apply_result|
        # Info: Applying configuration version '1505773208'
        # Info: 設定バージョン'1505767114'を適用しています。
        assert_match(/設定バージョン'[^']*'を適用しています。/, apply_result.stdout, "agent run does not contain 'Applying configuration version' translation")
        # Notice: Applied catalog in 0.03 seconds
        # Notice: カタログが適用されました。 0.01 秒
        assert_match(/カタログが適用されました。\s+[0-9.]*\s+秒/, apply_result.stdout, "agent run does not contain 'Applied catalog' translation")
      end
    end
  end
end
