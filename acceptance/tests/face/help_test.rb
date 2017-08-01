test_name 'Test `puppet help` workflow' do

  tag 'risk:medium',
      'audit:low',
      'audit:unit' # basic command line handling

  agents.each do |agent|

    faces = {}
    faces_array = []

    # I want to see a list of faces when using `puppet help`
    # NOTE: I'm breaking after the faces section because `puppet help not-face`
    # seems to just cat the man page...
    step 'Run `puppet help` and save a list of faces from it'
    on agent, puppet('help') do
      processing_faces = false
      stdout.each_line do |line|
        (processing_faces = true and next) if line =~ /^Available subcommands/
        processing_faces = false if line =~ /^\s*$/

        next unless processing_faces
        faces_array << line.match(/^\s{2,}\w+/).to_s.strip
      end
    end

    # When using `puppet help {face} I want to be able to get standard info
    # for each puppet face, including usage, options, and actions.
    # NOTE: I believe these are the three standards?
    faces_array.each do |face|
      faces[face] = []
      next if face == 'help'

      step "Use `puppet help #{face}`"

      on agent, puppet("help #{face} | grep USAGE") do
        assert_match /^USAGE:/, stdout,
          "There is NO usage section for 'puppet help #{face}'"
      end
    end
  end

end
