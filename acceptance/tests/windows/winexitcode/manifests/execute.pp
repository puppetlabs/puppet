define winexitcode::execute (
  $exit_code = 0,
) {

include winexitcode

  exec { "testcommand_${exit_code}":
    command   => "c:\\Windows\\System32\\cmd.exe /c c:\\tmp\\test.bat ${title}",
    returns   => $exit_code,
    logoutput => true,
    require   => Class['winexitcode'],
  }
}
