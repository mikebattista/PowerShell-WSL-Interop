function Import-WSLCommands() {
    <#
    .SYNOPSIS
    Import Linux commands into the session as PowerShell functions with argument completion.

    .DESCRIPTION
    WSL enables calling Linux commands directly within PowerShell via wsl.exe (e.g. wsl ls). While more convenient
    than a full context switch into WSL, it has the following limitations:

    * Prefixing commands with wsl is tedious and unnatural
    * Windows paths passed as arguments don't often resolve due to backslashes being interpreted as escape characters rather than directory separators
    * Windows paths passed as arguments don't often resolve due to not being translated to the appropriate mount point under /mnt within WSL
    * Default parameters defined in WSL login profiles with aliases and environment variables aren’t honored
    * Linux path completion is not supported
    * Command completion is not supported
    * Argument completion is not supported
    
    This function addresses these issues in the following ways:
    
    * By creating PowerShell function wrappers for common commands, prefixing them with wsl is no longer necessary
    * By identifying path arguments and converting them to WSL paths, path resolution is natural and intuitive as it translates seamlessly between Windows and WSL paths
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
    $commands = "awk", "emacs", "grep", "head", "less", "ls", "man", "sed", "seq", "ssh", "tail", "vim"

    # Register a function for each command.
    $commands | ForEach-Object { Invoke-Expression @"
    Remove-Alias $_ -Force -ErrorAction Ignore
    function global:$_() {
        for (`$i = 0; `$i -lt `$args.Count; `$i++) {
            # If a path is absolute with a qualifier (e.g. C:), run it through wslpath to map it to the appropriate mount point.
            if (Split-Path `$args[`$i] -IsAbsolute -ErrorAction Ignore) {
                `$args[`$i] = Format-WSLArgument (wsl.exe wslpath (`$args[`$i] -replace "\\", "/"))
            # If a path is relative, the current working directory will be translated to an appropriate mount point, so just format it.
            } elseif (Test-Path -IsValid `$args[`$i] -ErrorAction Ignore) {
                `$args[`$i] = Format-WSLArgument (`$args[`$i] -replace "\\", "/")
            }
        }

        if (`$null -eq `$WSLDefaultParameterValues -or (`$null -ne `$WSLDefaultParameterValues["Disabled"] -and `$WSLDefaultParameterValues["Disabled"] -eq `$true)) {
            if (`$input.MoveNext()) {
                `$input.Reset()
                `$input | wsl.exe $_ (`$args -split ' ')
            } else {
                wsl.exe $_ (`$args -split ' ')
            }
        } else {
            if (`$input.MoveNext()) {
                `$input.Reset()
                `$input | wsl.exe $_ (`$WSLDefaultParameterValues[`"$_`"] -split ' ') (`$args -split ' ')
            } else {
                wsl.exe $_ (`$WSLDefaultParameterValues[`"$_`"] -split ' ') (`$args -split ' ')                
            }
        }
    }
"@
    }
    
    # Register an ArgumentCompleter that shims bash's programmable completion.
    Register-ArgumentCompleter -CommandName $commands -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        # Map the command to the appropriate bash completion function.
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
        
        # Populate bash programmable completion variables.
        $COMP_LINE = "`"$commandAst`""
        $COMP_WORDS = "('$($commandAst.CommandElements.Extent.Text -join "' '")')" -replace "''", "'"
        for ($i = 1; $i -lt $commandAst.CommandElements.Count; $i++) {
            $extent = $commandAst.CommandElements[$i].Extent
            if ($cursorPosition -lt $extent.EndColumnNumber) {
                # The cursor is in the middle of a word to complete.
                $previousWord = $commandAst.CommandElements[$i - 1].Extent.Text
                $COMP_CWORD = $i
                break
            } elseif ($cursorPosition -eq $extent.EndColumnNumber) {
                # The cursor is immediately after the current word.
                $previousWord = $extent.Text
                $COMP_CWORD = $i + 1
                break
            } elseif ($cursorPosition -lt $extent.StartColumnNumber) {
                # The cursor is within whitespace between the previous and current words.
                $previousWord = $commandAst.CommandElements[$i - 1].Extent.Text
                $COMP_CWORD = $i
                break
            } elseif ($i -eq $commandAst.CommandElements.Count - 1 -and $cursorPosition -gt $extent.EndColumnNumber) {
                # The cursor is within whitespace at the end of the line.
                $previousWord = $extent.Text
                $COMP_CWORD = $i + 1
                break
            }
        }

        # Repopulate bash programmable completion variables for scenarios like '/mnt/c/Program Files'/<TAB> where <TAB> should continue completing the quoted path.
        $currentExtent = $commandAst.CommandElements[$COMP_CWORD].Extent
        $previousExtent = $commandAst.CommandElements[$COMP_CWORD - 1].Extent
        if ($currentExtent.Text -like "/*" -and $currentExtent.StartColumnNumber -eq $previousExtent.EndColumnNumber) {
            $COMP_LINE = $COMP_LINE -replace "$($previousExtent.Text)$($currentExtent.Text)", $wordToComplete
            $COMP_WORDS = $COMP_WORDS -replace "$($previousExtent.Text) '$($currentExtent.Text)'", $wordToComplete
            $previousWord = $commandAst.CommandElements[$COMP_CWORD - 2].Extent.Text
            $COMP_CWORD -= 1
        }

        # Build the command to pass to WSL.
        $command = $commandAst.CommandElements[0].Value
        $bashCompletion = ". /usr/share/bash-completion/bash_completion 2> /dev/null"
        $commandCompletion = ". /usr/share/bash-completion/completions/$command 2> /dev/null"
        $COMPINPUT = "COMP_LINE=$COMP_LINE; COMP_WORDS=$COMP_WORDS; COMP_CWORD=$COMP_CWORD; COMP_POINT=$cursorPosition"
        $COMPGEN = "bind `"set completion-ignore-case on`" 2> /dev/null; $F `"$command`" `"$wordToComplete`" `"$previousWord`" 2> /dev/null"
        $COMPREPLY = "IFS=`$'\n'; echo `"`${COMPREPLY[*]}`""
        $commandLine = "$bashCompletion; $commandCompletion; $COMPINPUT; $COMPGEN; $COMPREPLY" -split ' '

        # Invoke bash completion and return CompletionResults.
        $previousCompletionText = ""
        if ($wordToComplete -like "*=") {
            (wsl.exe $commandLine) -split '\n' |
            Sort-Object -Unique -CaseSensitive |
            ForEach-Object {
                $completionText = Format-WSLArgument ($wordToComplete + $_) $true
                $listItemText = $completionText
                if ($completionText -eq $previousCompletionText) {
                    # Differentiate completions that differ only by case otherwise PowerShell will view them as duplicate.
                    $listItemText += ' '
                }
                $previousCompletionText = $completionText
                [System.Management.Automation.CompletionResult]::new($completionText, $listItemText, 'ParameterName', $completionText)
            }
        } else {
            (wsl.exe $commandLine) -split '\n' |
            Where-Object { $commandAst.CommandElements.Extent.Text -notcontains $_ } |
            Sort-Object -Unique -CaseSensitive |
            ForEach-Object {
                $completionText = Format-WSLArgument $_ $true
                $listItemText = $completionText
                if ($completionText -eq $previousCompletionText) {
                    # Differentiate completions that differ only by case otherwise PowerShell will view them as duplicate.
                    $listItemText += ' '
                }
                $previousCompletionText = $completionText
                [System.Management.Automation.CompletionResult]::new($completionText, $listItemText, 'ParameterName', $completionText)
            }
        }
    }

    # Helper function to escape characters in arguments passed to WSL that would otherwise be misinterpreted.
    function global:Format-WSLArgument([string]$arg, [bool]$interactive) {
        if ($interactive -and $arg.Contains(" ")) {
            return "'$arg'"
        } else {
            return ($arg -replace " ", "\ ") -replace "([()|])", ('\$1', '`$1')[$interactive]
        }
    }
}

Import-WSLCommands