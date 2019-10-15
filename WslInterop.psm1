function global:Import-WslCommand() {
    <#
    .SYNOPSIS
    Import Linux commands into the session as PowerShell functions with argument completion.

    .DESCRIPTION
    WSL enables calling Linux commands directly within PowerShell via wsl.exe (e.g. wsl ls). While more convenient
    than a full context switch into WSL, it has the following limitations:

    * Prefixing commands with wsl is tedious and unnatural
    * Windows paths passed as arguments don't often resolve due to backslashes being interpreted as escape characters rather than directory separators
    * Windows paths passed as arguments don't often resolve due to not being translated to the appropriate mount point within WSL
    * Default parameters defined in WSL login profiles with aliases and environment variables aren’t honored
    * Linux path completion is not supported
    * Command completion is not supported
    * Argument completion is not supported
    
    This function addresses these issues in the following ways:
    
    * By creating PowerShell function wrappers for commands, prefixing them with wsl is no longer necessary
    * By identifying path arguments and converting them to WSL paths, path resolution is natural and intuitive as it translates seamlessly between Windows and WSL paths
    * Default parameters are supported by $WslDefaultParameterValues similar to $PSDefaultParameterValues
    * Environment variables are supported by $WslEnvironmentVariables
    * Command completion is enabled by PowerShell's command completion
    * Argument completion is enabled by registering an ArgumentCompleter that shims bash's programmable completion

    The commands can receive both pipeline input as well as their corresponding arguments just as if they were native to Windows.

    Additionally, they will honor any default parameters defined in a hash table called $WslDefaultParameterValues similar to $PSDefaultParameterValues. For example:

    * $WslDefaultParameterValues["grep"] = "-E"
    * $WslDefaultParameterValues["less"] = "-i"
    * $WslDefaultParameterValues["ls"] = "-AFh --group-directories-first"

    If you use aliases or environment variables within your login profiles to set default parameters for commands, define a hash table called $WslDefaultParameterValues within
    your PowerShell profile and populate it as above for a similar experience.

    Environment variables can also be set in a hash table called $WslEnvironmentVariables using the pattern $WslEnvironmentVariables["<NAME>"] = "<VALUE>".

    The import of these functions replaces any PowerShell aliases that conflict with the commands.

    .PARAMETER Command
    Specifies the commands to import.

    .EXAMPLE
    Import-WslCommand "awk", "emacs", "grep", "head", "less", "ls", "man", "sed", "seq", "ssh", "tail", "vim"
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Command
    )

    # Register a function for each command.
    $Command | ForEach-Object { Invoke-Expression @"
    Remove-Alias $_ -Scope Global -Force -ErrorAction Ignore
    function global:$_() {
        # Translate path arguments and format special characters.
        for (`$i = 0; `$i -lt `$args.Count; `$i++) {
            if (`$null -eq `$args[`$i]) {
                continue
            }

            # If a path is absolute with a qualifier (e.g. C:), run it through wslpath to map it to the appropriate mount point.
            if (Split-Path `$args[`$i] -IsAbsolute -ErrorAction Ignore) {
                `$args[`$i] = Format-WslArgument (wsl.exe wslpath (`$args[`$i] -replace "\\", "/"))
            # If a path is relative, the current working directory will be translated to an appropriate mount point, so just format it.
            } elseif (Test-Path `$args[`$i] -ErrorAction Ignore) {
                `$args[`$i] = Format-WslArgument (`$args[`$i] -replace "\\", "/")
            # Otherwise, format special characters.
            } else {
                `$args[`$i] = Format-WslArgument `$args[`$i]
            }
        }

        # Build the command to pass to WSL.
        `$environmentVariables = ((`$WslEnvironmentVariables.Keys | ForEach-Object { "`$_='`$(`$WslEnvironmentVariables."`$_")'" }), "")[`$WslEnvironmentVariables.Count -eq 0]
        `$defaultArgs = (`$WslDefaultParameterValues."$_", "")[`$WslDefaultParameterValues.Disabled -eq `$true]
        `$commandLine = "`$environmentVariables $_ `$defaultArgs `$args" -split ' '

        # Invoke the command.
        if (`$input.MoveNext()) {
            `$input.Reset()
            `$input | wsl.exe `$commandLine
        } else {
            wsl.exe `$commandLine
        }
    }
"@
    }
    
    # Register an ArgumentCompleter that shims bash's programmable completion.
    Register-ArgumentCompleter -CommandName $Command -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        
        # Identify the command.
        $command = $commandAst.CommandElements[0].Value

        # Initialize the bash completion function cache.
        $WslCompletionFunctionsCache = "$Env:APPDATA\PowerShell WSL Interop\WslCompletionFunctions"
        if ($null -eq $global:WslCompletionFunctions) {
            if (Test-Path $WslCompletionFunctionsCache) {
                $global:WslCompletionFunctions = Import-Clixml $WslCompletionFunctionsCache
            } else {
                $global:WslCompletionFunctions = @{}
            }
        }

        # Map the command to the appropriate bash completion function.
        if (-not $global:WslCompletionFunctions.Contains($command)) {
            # Try to find the completion function.
            $global:WslCompletionFunctions[$command] = wsl.exe (". /usr/share/bash-completion/bash_completion 2> /dev/null; __load_completion $command 2> /dev/null; complete -p $command 2> /dev/null | sed -E 's/^complete.*-F ([^ ]+).*`$/\1/'" -split ' ')
            
            # If we can't find a completion function, default to _minimal which will resolve Linux file paths.
            if ($null -eq $global:WslCompletionFunctions[$command] -or $global:WslCompletionFunctions[$command] -like "complete*") {
                $global:WslCompletionFunctions[$command] = "_minimal"
            }

            # Update the bash completion function cache.
            New-Item $WslCompletionFunctionsCache -Force | Out-Null
            $global:WslCompletionFunctions | Export-Clixml $WslCompletionFunctionsCache
        }

        # Populate bash programmable completion variables.
        $COMP_LINE = "`"$commandAst`""
        $COMP_WORDS = "('$($commandAst.CommandElements.Extent.Text -join "' '")')" -replace "''", "'"
        $previousWord = $commandAst.CommandElements[0].Value
        $COMP_CWORD = 1
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
        $bashCompletion = ". /usr/share/bash-completion/bash_completion 2> /dev/null"
        $commandCompletion = "__load_completion $command 2> /dev/null"
        $COMPINPUT = "COMP_LINE=$COMP_LINE; COMP_WORDS=$COMP_WORDS; COMP_CWORD=$COMP_CWORD; COMP_POINT=$cursorPosition"
        $COMPGEN = "bind `"set completion-ignore-case on`" 2> /dev/null; $($WslCompletionFunctions[$command]) `"$command`" `"$wordToComplete`" `"$previousWord`" 2> /dev/null"
        $COMPREPLY = "IFS=`$'\n'; echo `"`${COMPREPLY[*]}`""
        $commandLine = "$bashCompletion; $commandCompletion; $COMPINPUT; $COMPGEN; $COMPREPLY" -split ' '

        # Invoke bash completion and return CompletionResults.
        $previousCompletionText = ""
        (wsl.exe $commandLine) -split '\n' |
        Sort-Object -Unique -CaseSensitive |
        ForEach-Object {
            if ($_ -eq "") {
                continue
            }

            if ($wordToComplete -match "(.*=).*") {
                $completionText = Format-WslArgument ($Matches[1] + $_) $true
                $listItemText = $_
            } else {
                $completionText = Format-WslArgument $_ $true
                $listItemText = $completionText
            }

            if ($completionText -eq $previousCompletionText) {
                # Differentiate completions that differ only by case otherwise PowerShell will view them as duplicate.
                $listItemText += ' '
            }

            $previousCompletionText = $completionText
            [System.Management.Automation.CompletionResult]::new($completionText, $listItemText, 'ParameterName', $completionText)
        }
    }
}

function global:Format-WslArgument([string]$arg, [bool]$interactive) {
    <#
    .SYNOPSIS
    Format arguments passed to WSL to prevent them from being misinterpreted.
    #>

    $arg = $arg.Trim()

    if ($arg -like "[""']*[""']") {
        return $arg
    } elseif ($interactive -and $arg.Contains(" ")) {
        return "'$arg'"
    } else {
        $arg = $arg -replace "([ ,(){}|;])", ('\$1', '`$1')[$interactive]
        $arg = $arg -replace '(\\[a-zA-Z0-9])', '\$1'
        return $arg
    }
}