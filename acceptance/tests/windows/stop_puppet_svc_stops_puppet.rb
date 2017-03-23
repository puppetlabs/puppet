test_name '(C14941) Stopping puppet service on Windows stops puppet' do

  confine :to, :platform => 'windows'
  
  opts = {
    :acceptable_exit_codes => [0],
  }
    
  # Wait for the puppet service to enter the requested state and return
  # after at most 5 attempts 
  def wait_for_windows_puppet_service_state(state, options=opts)
    options ||= {
      :acceptable_exit_codes => [0],
    }

    query = on(agent, 'sc query puppet', options)
    unless query.stdout.include?(state)
      repeat_fibonacci_style_for 5 do
        result = on(agent, 'sc query puppet', options)
        return result if result.stdout.include?(state)
      end
    end
    query = on(agent, 'sc query puppet', options)
    assert_match(/#{state}/, result.stdout)
  end

  agents.each do
    step 'Verify the puppet service is running' do
      # Exit code 32 means the service is already running, so add this
      # value at block scope to the list of okay exit codes
      opts[:acceptable_exit_codes] << 32
      start = on(agent, 'sc start puppet', opts)
      wait_for_windows_puppet_service_state('RUNNING', opts)
    end
   
    step 'Stop the puppet service and verify it stopped' do
      stop = on(agent, 'sc stop puppet', opts)
      wait_for_windows_puppet_service_state('STOPPED')
    end
  
    step 'Restart the puppet service and verify it restarted' do
      restart = on(agent, 'sc start puppet', opts)
      wait_for_windows_puppet_service_state('RUNNING')
    end
  end

end
