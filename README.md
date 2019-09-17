# PowerShell-WSL-Interop

WSL enables calling Linux commands directly within PowerShell via `wsl.exe` (e.g. `wsl date`). While more convenient
than a full context switch into WSL, it has the following limitations:

* Prefixing commands with `wsl` is tedious and unnatural
* Windows paths passed as arguments don't often resolve due to backslashes being interpreted as escape characters rather than directory separators
* Windows paths passed as arguments don't often resolve due to not being translated to the appropriate mount point under `/mnt` within WSL
* Default parameters defined in WSL login profiles with aliases and environment variables aren’t honored
* Linux path completion is not supported
* Command completion is not supported
* Argument completion is not supported

This function addresses those issues in the following ways:

* By creating PowerShell function wrappers for common commands, prefixing them with `wsl` is no longer necessary
* By identifying path arguments and converting them to WSL paths, path resolution is natural as it translates seamlessly between Windows and WSL paths
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