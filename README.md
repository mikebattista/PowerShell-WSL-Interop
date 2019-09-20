# PowerShell WSL Interop

The [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/about) enables calling Linux commands directly within PowerShell via `wsl.exe` (e.g. `wsl ls`). While more convenient than a full context switch into WSL, it has the following limitations:

* Prefixing commands with `wsl` is tedious and unnatural
* Windows paths passed as arguments don't often resolve due to backslashes being interpreted as escape characters rather than directory separators
* Windows paths passed as arguments don't often resolve due to not being translated to the appropriate mount point under `/mnt` within WSL
* Default parameters defined in WSL login profiles with aliases and environment variables aren’t honored
* Linux path completion is not supported
* Command completion is not supported
* Argument completion is not supported

The `Import-WSLCommands` function addresses these issues in the following ways:

* By creating PowerShell function wrappers for common commands, prefixing them with `wsl` is no longer necessary
* By identifying path arguments and converting them to WSL paths, path resolution is natural and intuitive as it translates seamlessly between Windows and WSL paths
* Default parameters are supported by `$WSLDefaultParameterValues` similar to `$PSDefaultParameterValues`
* Command completion is enabled by PowerShell's command completion
* Argument completion is enabled by registering an `ArgumentCompleter` that shims bash's programmable completion

The commands can receive both pipeline input as well as their corresponding arguments just as if they were native to Windows.

Additionally, they will honor any default parameters defined in a hash table called `$WSLDefaultParameterValues` similar to `$PSDefaultParameterValues`. For example:

```powershell
$WSLDefaultParameterValues["grep"] = "-E"
$WSLDefaultParameterValues["less"] = "-i"
$WSLDefaultParameterValues["ls"] = "-AFh --group-directories-first"
$WSLDefaultParameterValues["sed"] = "-E"
```

If you use aliases or environment variables within your login profiles to set default parameters for commands, define a hash table called `$WSLDefaultParameterValues` within
your PowerShell profile and populate it as above for a similar experience.

The import of these functions replaces any PowerShell aliases that conflict with the commands.

## Usage

* Install [PowerShell Core](https://github.com/powershell/powershell#get-powershell)
* Install the [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
* Add the contents of [PowerShell WSL Interop.ps1](https://github.com/mikebattista/PowerShell-WSL-Interop/blob/master/PowerShell%20WSL%20Interop.ps1) to your [PowerShell profile](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-6)
* Set `$commands` within `Import-WSLCommands` to the list of commands you'd like to import
* (Optionally) Update the `$F` switch within `Import-WSLCommands` to map the commands to the bash completion functions returned by `complete | grep <COMMAND>$` within bash (e.g. `complete -F _longopt less` means bash uses the `_longopt` function to complete for `less`)
    * Note: bash loads shell completion functions on demand for many commands so you may need to attempt argument completion within bash first for a given command before `complete` will return its completion spec.
* (Optionally) Define a [hash table](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_hash_tables?view=powershell-6#creating-hash-tables) called `$WSLDefaultParameterValues` and set default arguments for commands using the pattern `$WSLDefaultParameterValues["<COMMAND>"] = "<ARGS>"`

## Known Issues

* Windows PowerShell is not supported. [PowerShell Core](https://github.com/powershell/powershell#get-powershell) is required.
* PowerShell treats parameters as case-insensitive so will not differentiate between CompletionResults that only differ by case (e.g. -a and -A). Completion results returned by bash that only differ by case will be treated as one CompletionResult. You can still pass both variants on the command line, but argument completion will only present one.