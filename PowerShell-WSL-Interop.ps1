function ConvertTo-WSLPath([string] $path) {
    <#
    .SYNOPSIS
    Convert a Windows path to a WSL path.

    .DESCRIPTION
    Replace backward slashes with forward slashes and map absolute paths to the appropriate
    mount point under /mnt within WSL.
    #>

    $path = $path -replace "\\", "/"
                
    if ($path -match "^(\w):") {
        $path = $path -replace $matches[0], "/mnt/$($matches[1].ToLower())"
    }

    return $path
}

function Import-WSLCommands() {
    <#
    .SYNOPSIS
    Import Linux commands into the session as PowerShell functions with argument completion.

    .DESCRIPTION
    WSL enables calling Linux commands directly within PowerShell via wsl.exe (e.g. wsl date). While more convenient
    than a full context switch into WSL, it has the following limitations:

    * Prefixing commands with wsl is tedious and unnatural
    * Windows paths passed as arguments don't often resolve due to backslashes being interpreted as escape characters rather than directory separators
    * Windows paths passed as arguments don't often resolve due to not being translated to the appropriate mount point under /mnt within WSL
    * Default parameters defined in WSL login profiles with aliases and environment variables aren’t honored
    * Linux path completion is not supported
    * Command completion is not supported
    * Argument completion is not supported
    
    This function addresses those issues in the following ways:
    
    * By creating PowerShell function wrappers for common commands, prefixing them with wsl is no longer necessary
    * By identifying path arguments and converting them to WSL paths, path resolution is natural as it translates seamlessly between Windows and WSL paths
    * Default parameters are supported by $WSLDefaultParameterValues similar to $PSDefaultParameterValues
    * Command completion is enabled by PowerShell's command completion
    * Argument completion is enabled by registering an ArgumentCompleter that shims bash's programmable completion

    The commands can receive both pipeline input as well as their corresponding arguments just as if they were native to Windows.

    Additionally, they will honor any default parameters defined in a hash table called $WSLDefaultParameterValues similar to $PSDefaultParameterValues. For example:

    * $WSLDefaultParameterValues["grep"] = "-E"
    * $WSLDefaultParameterValues["less"] = "-i"
    * $WSLDefaultParameterValues["ls"] = "-AFh --group-directories-first"
    * $WSLDefaultParameterValues["sed"] = "-E"

    If you use aliases or environment variables within your login profiles to set default parameters for commands, define a hash table called $WSLDefaultParameterValues within
    your PowerShell profile and populate it as above for a similar experience.

    The import of these functions replaces any PowerShell aliases that conflict with the commands.
    #>

    # The commands to import.
    $commands = "awk", "grep", "head", "less", "ls", "man", "sed", "seq", "ssh", "tail", "vim"

    # Register a function for each command.
    $commands | ForEach-Object { Invoke-Expression @"
    Remove-Alias $_ -Force -ErrorAction Ignore
    function global:$_() {
        for (`$i = 0; `$i -lt `$args.Length; `$i++) {
            if (Test-Path `$args[`$i] -ErrorAction Ignore) {
                `$args[`$i] = ConvertTo-WSLPath `$args[`$i]
            }
        }

        if (`$null -eq `$WSLDefaultParameterValues) {
            `$input | wsl.exe $_ @args
        } elseif (`$null -ne `$WSLDefaultParameterValues["Disabled"] -and `$WSLDefaultParameterValues["Disabled"] -eq `$true) {
            `$input | wsl.exe $_ @args
        } else {
            `$input | wsl.exe $_ (`$WSLDefaultParameterValues[`"$_`"] -split ' ') @args
        }
    }
"@
    }
    
    # Register an ArgumentCompleter that shims bash's programmable completion.
    Register-ArgumentCompleter -CommandName $commands -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        $F = switch ($commandAst.CommandElements[0].Value) {
            {$_ -in "awk", "grep", "head", "less", "ls", "sed", "seq", "tail"} {
                "_longopt"
                break
            }

            "man" {
                "_man"
                break
            }

            "ssh" {
                "_ssh"
                break
            }

            Default {
                "_minimal"
                break
            }
        }
        
        $COMP_LINE = "`"$commandAst`""
        $COMP_WORDS = "($($commandAst.CommandElements.Extent.Text -join ' '))"
        for ($i = 0; $i -lt $commandAst.CommandElements.Count; $i++) {
            $extent = $commandAst.CommandElements[$i].Extent
            if ($cursorPosition -lt $extent.EndColumnNumber) {
                $previousWord = $commandAst.CommandElements[[System.Math]::Max(0, $i - 1)].Extent.Text
                $COMP_CWORD = $i
                break
            } elseif ($cursorPosition -eq $extent.EndColumnNumber) {
                $previousWord = $extent.Text
                $COMP_CWORD = $i + 1
                break
            } elseif ($cursorPosition -lt $extent.StartColumnNumber) {
                $previousWord = $commandAst.CommandElements[[System.Math]::Max(0, $i - 1)].Extent.Text
                $COMP_CWORD = $i
                break
            } elseif ($i -eq $commandAst.CommandElements.Count - 1 -and $cursorPosition -gt $extent.EndColumnNumber) {
                $previousWord = $extent.Text
                $COMP_CWORD = $i + 1
                break
            }
        }

        $command = $commandAst.CommandElements[0].Value
        $bashCompletion = ". /usr/share/bash-completion/bash_completion 2> /dev/null"
        $commandCompletion = ". /usr/share/bash-completion/completions/$command 2> /dev/null"
        $COMPINPUT = "COMP_LINE=$COMP_LINE; COMP_WORDS=$COMP_WORDS; COMP_CWORD=$COMP_CWORD; COMP_POINT=$cursorPosition"
        $COMPGEN = "$F `"$command`" `"$wordToComplete`" `"$previousWord`" 2> /dev/null"
        $COMPREPLY = "echo `${COMPREPLY[@]}"
        $commandLine = "$bashCompletion; $commandCompletion; $COMPINPUT; $COMPGEN; $COMPREPLY" -split ' '

        if ($wordToComplete -like "*=") {
            (wsl.exe $commandLine) -split ' ' |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($wordToComplete + $_, $_, 'ParameterName', $_) }
        } else {
            (wsl.exe $commandLine) -split ' ' |
            Where-Object { $commandAst.CommandElements.Extent.Text -notcontains $_ } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_) }
        }
    }
}

Import-WSLCommands