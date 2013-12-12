$name = 'default'

function Touch-File([string]$file)
{
  if (Test-Path $file) { (Get-ChildItem $file).LastWriteTime = Get-Date }
  else { echo $null > $file }
}

function Get-CurrentDirectory
{
  $thisName = $MyInvocation.MyCommand.Name
  [IO.Path]::GetDirectoryName((Get-Content function:$thisName).File)
}

$cmdLine = $args
if ($args.Length -gt 0)
{
  $name = $args[0]
  $cmdLine = $args[1..($args.Length)]
}

$dir = "$HOME\test\master\$name"
# $dataDir = [Environment]::GetFolderPath('CommonApplicationData')
if (!(Test-Path $dir)) { New-Item -Type Directory $dir }

$authConfSrc = "~\auth.conf"
$authConfDest = "$dir\auth.conf"
if ((Test-Path $authConfSrc) -and !(Test-Path $authConfDest))
{
  # Edit this file to change default puppet authorizations.
  Copy-Item $authConfSrc $authConfDest
}

$manifestPath = "$dir\manifests"
if (!(Test-Path $manifestPath)) { New-Item -Type Directory $manifestPath }
Touch-File "$dir\manifests\site.pp"

# Work around Redmine #21908 where the master generates a warning if agent pluginsyncs
# and there isn't at least one module with a libdir.
$libPath = "$dir\modules\foo\lib"
if (!(Test-Path $libPath)) { New-Item -Type Directory $libPath }

Push-Location "$(Get-CurrentDirectory)\.."
$puppet = @(
  '--no-daemonize',
  '--trace',
  '--autosign=true',
  '--debug',
  "--confdir=""$dir""",
  "--vardir=""$dir""",
  '--certname',
  'puppetmaster'
)
$puppet += $cmdLine

Write-Host $puppet
bundle exec puppet master $puppet
