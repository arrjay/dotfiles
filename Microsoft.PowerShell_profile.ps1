<# PowerShell 2.0 profile #>

# hacky way to run git-crypt from PS1 via PATH munging
function git-crypt {
  # inject paths needed from compilation to run this and go
  $gcargs = $args
  & { $env:PATH="c:\mingw\bin;$env:HOMEDRIVE$env:HOMEPATH\applications\libressl-2.4.2-windows\x86;$env:PATH"
      Invoke-Expression "$env:HOMEDRIVE$env:HOMEPATH\src\git-crypt\git-crypt.exe $gcargs"
    }
}

# command aliases
New-Alias which Get-Command