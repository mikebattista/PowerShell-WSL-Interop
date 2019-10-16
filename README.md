# PowerShell WSL Interop

The [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/about) enables calling Linux commands directly within PowerShell via `wsl.exe` (e.g. `wsl ls`). While more convenient than a full context switch into WSL, it has the following limitations:

* Prefixing commands with `wsl` is tedious and unnatural
* Windows paths passed as arguments don't often resolve due to backslashes being interpreted as escape characters rather than directory separators
* Windows paths passed as arguments don't often resolve due to not being translated to the appropriate mount point within WSL
* Default parameters defined in WSL login profiles with aliases and environment variables aren’t honored
* Linux path completion is not supported
* Command completion is not supported
* Argument completion is not supported

The `Import-WslCommand` function addresses these issues in the following ways:

* By creating PowerShell function wrappers for commands, prefixing them with `wsl` is no longer necessary
* By identifying path arguments and converting them to WSL paths, path resolution is natural and intuitive as it translates seamlessly between Windows and WSL paths
* Default parameters are supported by `$WslDefaultParameterValues` similar to `$PSDefaultParameterValues`
* Environment variables are supported by `$WslEnvironmentVariables`
* Command completion is enabled by PowerShell's command completion
* Argument completion is enabled by registering an `ArgumentCompleter` that shims bash's programmable completion

The commands can receive both pipeline input as well as their corresponding arguments just as if they were native to Windows.

Additionally, they will honor any default parameters defined in a hash table called `$WslDefaultParameterValues` similar to `$PSDefaultParameterValues`. For example:

```powershell
$WslDefaultParameterValues["grep"] = "-E"
$WslDefaultParameterValues["less"] = "-i"
$WslDefaultParameterValues["ls"] = "-AFh --group-directories-first"
```

If you use aliases or environment variables within your login profiles to set default parameters for commands, define a hash table called `$WslDefaultParameterValues` within
your PowerShell profile and populate it as above for a similar experience.

Environment variables can also be set in a hash table called `$WslEnvironmentVariables` using the pattern `$WslEnvironmentVariables["<NAME>"] = "<VALUE>"`.

The import of these functions replaces any PowerShell aliases that conflict with the commands.

## Usage

* Install [PowerShell Core](https://github.com/powershell/powershell#get-powershell)
* Install the [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
* Install the WslInterop module with  `Install-Module WslInterop`
* Import commands with `Import-WslCommand` either from your profile for persistent access or on demand when you need a command (e.g. `Import-WslCommand "awk", "emacs", "grep", "head", "less", "ls", "man", "sed", "seq", "ssh", "tail", "vim"`)
* (Optionally) Define a [hash table](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_hash_tables?view=powershell-6#creating-hash-tables) called `$WslDefaultParameterValues` and set default arguments for commands using the pattern `$WslDefaultParameterValues["<COMMAND>"] = "<ARGS>"`
* (Optionally) Define a [hash table](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_hash_tables?view=powershell-6#creating-hash-tables) called `$WslEnvironmentVariables` and set environment variables using the pattern `$WslEnvironmentVariables["<NAME>"] = "<VALUE>"` or use [WSLENV](https://devblogs.microsoft.com/commandline/share-environment-vars-between-wsl-and-windows/)

## Known Issues

* Windows PowerShell is not supported. [PowerShell Core](https://github.com/powershell/powershell#get-powershell) is required.