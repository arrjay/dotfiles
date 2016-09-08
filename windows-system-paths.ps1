<# Powershell 2.0 Script #>

## Functions

# return if a directory is in the path via system or user registry hives (or both)
function pathcheck {
  [Cmdletbinding()]
  param(
    [parameter(Mandatory=$true, Position=1)]
    [string]$folder
  )

  $folder = $folder.TrimEnd('\')

  if (($userpath -contains $folder) -and ($syspath -contains $folder)) { "both"
  } elseif ($userpath -contains $folder)                               { "user"
  } elseif ($syspath -contains $folder)                                { "system"
  } else                                                               { $false }
}

# return if a binary is first in the PATH -or- if the fully qualified name exists
# else return False
function bincheck {
  [Cmdletbinding()]
  param(
    [parameter(Mandatory=$true, Position=1)]
    [string]$binary
  )

  $exec = Split-Path -leaf $binary

  $gcm = $(Get-Command $exec -ErrorAction SilentlyContinue)

  if ($gcm) {
    [string]$gcm.source.ToLower()
  } else {
    if (Test-Path $binary) {
      [string]$binary.ToLower()
    } else {
      $false
    }
  }
}

# return candidate "Program Files" names for a specified binary
function wow64 {
  [Cmdletbinding()]
  param(
    [parameter(Mandatory=$true, Position=1)]
    [string]$partialpath
  )

  [string[]] $paths = @()

  if (${Env:ProgramFiles(x86)}) {
    $paths = $paths + "${Env:ProgramFiles(x86)}\$partialpath"
  }

  $paths = $paths + "${Env:ProgramFiles}\$partialpath"

  $paths.ToLower()
}

# remember that the user path is appended to the system path.
# reset the path.
$env:PATH   = [System.Environment]::GetEnvironmentVariable("Path","Machine") +
        ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# pick up 'heavyweight' .Net ArrayList so we can _remove_ things
$syspath    = New-Object System.Collections.Generic.List[System.Object]
ForEach ($dir in $([System.Environment]::GetEnvironmentVariable("Path","Machine").split(";").TrimEnd('\'))) {
  $syspath.Add($dir.ToLower())
}

$userpath   = New-Object System.Collections.Generic.List[System.Object]
if ([System.Environment]::GetEnvironmentVariable("Path","User")) {
  ForEach ($dir in $([System.Environment]::GetEnvironmentVariable("Path","User").split(";").TrimEnd('\'))) {
    $userpath.Add($dir.ToLower())
  }
}
$userpath.Add("c:\program files\git\cmd".ToLower())

write-host "starting with expanded PATH $env:PATH"


# array of all the _possible_ paths to add
$paths = @()

# GnuPG - this code sets the path and GPG utility environment.
$gpgs = @()
$gpgs = $gpgs + $(wow64 "GNU\GnuPG\pub\gpg.exe")

ForEach ($candidate in $gpgs) {
  $found = $(bincheck $candidate)
  if ($found) {
    $paths = $paths + $($found | Split-Path -Parent)
    if (-not "${env:GNUPGHOME}") {
      # call gpg to create a homedir...
      & gpg -K | Out-Null
      if (Test-Path "${env:APPDATA}\GnuPG") {
        New-ItemProperty -Path HKCU:\Environment -Name GNUPGHOME -Value "%APPDATA%\GnuPG" -PropertyType ExpandString -Force | Out-Null
      }
    }
  }
}

# Putty/plink - this code also configures the git ssh transport
$plinks = @()
$plinks = $putties + $(wow64 "PuTTY\plink.exe")

ForEach ($candidate in $plinks) {
  $found = $(bincheck $candidate)
  if ($found) {
    $paths = $paths + $($found | Split-Path -Parent)
    if (-not "${env:GIT_SSH}") {
      New-ItemProperty -Path HKCU:\Environment -Name GIT_SSH -Value "plink.exe" -PropertyType ExpandString -Force | Out-Null
    }
  }
}

# Editplus - also configure EDITOR
$eps = @()
$eps = $eps + $(wow64 "EditPlus\editplus.exe")

ForEach ($candidate in $eps) {
  $found = $(bincheck $candidate)
  if ($found) {
    $paths = $paths + $($found | Split-Path -Parent)
    if (-not "${env:EDITOR}") {
      New-ItemProperty -Path HKCU:\Environment -Name EDITOR -Value "editplus.exe" -PropertyType ExpandString -Force | Out-Null
    }
  }
}

# git
$gits = @()
$gits = $gits + $(wow64 "Git\cmd\git.exe")

ForEach ($candidate in $gits) {
  $found = $(bincheck $candidate)
  if ($found) {
    $paths = $paths + $($found | Split-Path -Parent)
  }
}

# loop through $paths now for adding to path
ForEach ($path in $($paths | Get-Unique)) {
  $pc = pathcheck $path
  if (-not $pc) {
    $userpath.add($path)
  }
  if ($pc -eq "both") {
    $userpath.remove($path) | Out-Null
  }
}

# well known expansions
$evars = @{
# actually, don't add systemroot it's super obnoxious and special-cased out
# "%SystemRoot%"         = "$($env:SystemRoot.ToLower())\";
  "%ProgramFiles(x86)%"  = "$(${env:ProgramFiles(x86)}.ToLower())\";
  "%ProgramFiles%"       = "$($env:ProgramFiles.ToLower())\"
}

# copy to new envs
$_syspath     = New-Object System.Collections.Generic.List[System.Object]
$_userpath    = New-Object System.Collections.Generic.List[System.Object]

$sr = $env:SystemRoot.ToLower()

# loop through $paths substituting...
ForEach ($component in $userpath) {
  $_userpath.add($component.Replace($sr,"%SystemRoot%"))
  ForEach ($ekey in $evars.keys) {
    $esz = "$($evars.Item($ekey))"
    if ($component -like "$esz*") {
      $nc = $component.Replace($esz,"${ekey}\")
      $_userpath.remove($component) | Out-Null
      $_userpath.add($nc)
    }
  }
}

ForEach ($component in $syspath) {
  $_syspath.add($component.Replace($sr,"%SystemRoot%"))
  ForEach ($ekey in $evars.keys) {
    $esz = "$($evars.Item($ekey))"
    if ($component -like "$esz*") {
      $nc = $component.Replace($esz,"${ekey}\")
      $_syspath.remove($component) | Out-Null
      $_syspath.add($nc)
    }
  }
}

$_userpath = $_userpath | sort-object | get-unique
$_syspath  = $_syspath | sort-object | get-unique

# for system paths, move %systemroot% to the front again
$_fsyspath = New-Object System.Collections.Generic.List[System.Object]
$_psyspath = New-Object System.Collections.Generic.List[System.Object]
ForEach ($component in $_syspath) {
  if ($component -like "%SystemRoot%*") {
    $_psyspath.Add($component)
  } else {
    $_fsyspath.Insert(0,$component)
  }
}

$finsyspath = $_psyspath + $_fsyspath

# okay enough of that. make some strings.
$user_sz_path = $_userpath  -join ";"
$sys_sz_path  = $finsyspath -join ";"

write-host "setting User path to"
write-host "$user_sz_path"
New-ItemProperty -Path HKCU:\Environment -Name PATH -Value "$user_sz_path" -PropertyType ExpandString -Force | Out-Null
write-host "setting system path to "
write-host "$sys_sz_path"
New-ItemProperty -PATH "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" `
 -Name Path -Value "sys_sz_path" -PropertyType ExpandString -Force | Out-Null