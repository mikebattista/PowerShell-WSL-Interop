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
    * Command completion is enabled by PowerShell's command completion
    * Argument completion is enabled by registering an ArgumentCompleter that shims bash's programmable completion

    The commands can receive both pipeline input as well as their corresponding arguments just as if they were native to Windows.

    Additionally, they will honor any default parameters defined in a hash table called $WslDefaultParameterValues similar to $PSDefaultParameterValues. For example:

    * $WslDefaultParameterValues["grep"] = "-E"
    * $WslDefaultParameterValues["less"] = "-i"
    * $WslDefaultParameterValues["ls"] = "-AFh --group-directories-first"

    If you use aliases or environment variables within your login profiles to set default parameters for commands, define a hash table called $WslDefaultParameterValues within
    your PowerShell profile and populate it as above for a similar experience.

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

    # Register an alias for each command.
    $Command | ForEach-Object { Set-Alias $_ Invoke-WslCommand -Scope Global -Force }
    
    # Map the commands to the appropriate bash completion functions.
    $script:WslCompletionFunctionsCache = "$Env:APPDATA\PowerShell WSL Interop\WslCompletionFunctions"
    $script:WslCompletionFunctionsCacheUpdated = $false
    if ($null -eq $global:WslCompletionFunctions) {
        if (Test-Path $script:WslCompletionFunctionsCache) {
            $global:WslCompletionFunctions = Import-Clixml $script:WslCompletionFunctionsCache
        } else {
            $global:WslCompletionFunctions = @{}
        }
    }
    $Command | ForEach-Object {
        if (-not $global:WslCompletionFunctions.Contains($_)) {
            # Try to find the completion function.
            $global:WslCompletionFunctions[$_] = wsl.exe (". /usr/share/bash-completion/bash_completion 2> /dev/null; . /usr/share/bash-completion/completions/$_ 2> /dev/null; complete -p $_ 2> /dev/null | sed -E 's/^complete.*-F ([^ ]+).*`$/\1/'" -split ' ')
            
            # If we can't find a completion function, default to _minimal which will resolve Linux file paths.
            if ($null -eq $global:WslCompletionFunctions[$_] -or $global:WslCompletionFunctions[$_] -like "complete*") {
                $global:WslCompletionFunctions[$_] = "_minimal"
            }

            # Set the cache updated flag.
            $script:WslCompletionFunctionsCacheUpdated = $true
        }
    }
    if ($script:WslCompletionFunctionsCacheUpdated) {
        New-Item $script:WslCompletionFunctionsCache -Force | Out-Null
        $global:WslCompletionFunctions | Export-Clixml $script:WslCompletionFunctionsCache
    }
    
    # Register an ArgumentCompleter that shims bash's programmable completion.
    Register-ArgumentCompleter -CommandName $Command -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        
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
        $command = $commandAst.CommandElements[0].Value
        $bashCompletion = ". /usr/share/bash-completion/bash_completion 2> /dev/null"
        $commandCompletion = ". /usr/share/bash-completion/completions/$command 2> /dev/null"
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

function global:Invoke-WslCommand() {
    <#
    .SYNOPSIS
    The base function for command aliases imported with Import-WslCommand.
    #>

    # Identify the command.
    $command = $MyInvocation.InvocationName
    if ($command -eq '&') {
        $MyInvocation.Line -match '&\s+(["''$]?[^ ]+["'']?)' | Out-Null
        if ($Matches[1] -like '$*') {
            $command = $ExecutionContext.InvokeCommand.ExpandString($Matches[1])
        } else {
            $command = $Matches[1]
        }
    }

    # Translate path arguments.
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($null -eq $args[$i]) {
            continue
        }

        # If a path is absolute with a qualifier (e.g. C:), run it through wslpath to map it to the appropriate mount point.
        if (Split-Path $args[$i] -IsAbsolute -ErrorAction Ignore) {
            $args[$i] = Format-WslArgument (wsl.exe wslpath ($args[$i] -replace "\\", "/"))
        # If a path is relative, the current working directory will be translated to an appropriate mount point, so just format it.
        } elseif (Test-Path $args[$i] -ErrorAction Ignore) {
            $args[$i] = Format-WslArgument ($args[$i] -replace "\\", "/")
        }
    }

    # Invoke the command.
    $defaultArgs = (($WslDefaultParameterValues."$command" -split ' '), "")[$WslDefaultParameterValues.Disabled -eq $true]
    if ($input.MoveNext()) {
        $input.Reset()
        $input | wsl.exe $command $defaultArgs ($args -split ' ')
    } else {
        wsl.exe $command $defaultArgs ($args -split ' ')
    }
}

function global:Format-WslArgument([string]$arg, [bool]$interactive) {
    <#
    .SYNOPSIS
    Format arguments passed to WSL to prevent them from being misinterpreted.
    #>

    $arg = $arg.Trim()
    if ($interactive -and $arg.Contains(" ")) {
        return "'$arg'"
    } else {
        return ($arg -replace " ", "\ ") -replace "([()|])", ('\$1', '`$1')[$interactive]
    }
}