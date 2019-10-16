Import-Module .\WslInterop.psd1 -Force

Describe "Import-WslCommand" {
    It "Creates function wrappers and removes any conflicting aliases." -TestCases @(
        @{command = 'awk'},
        @{command = 'emacs'},
        @{command = 'grep'},
        @{command = 'head'},
        @{command = 'less'},
        @{command = 'ls'},
        @{command = 'man'},
        @{command = 'sed'},
        @{command = 'seq'},
        @{command = 'ssh'},
        @{command = 'tail'},
        @{command = 'vim'}
    ) {
        param([string]$command)

        Set-Alias $command help -Scope Global -Force -ErrorAction Ignore

        Import-WslCommand $command

        Get-Command $command | Select-Object -ExpandProperty CommandType | Should -BeExactly "Function"
    }

    It "Enables calling commands with arbitrary arguments." -TestCases @(
        @{command = 'seq'; arguments = '0 10' -split ' '; expectedResult = '0 1 2 3 4 5 6 7 8 9 10' -split ' '},
        @{command = 'seq'; arguments = '0 2 10' -split ' '; expectedResult = '0 2 4 6 8 10' -split ' '},
        @{command = 'seq'; arguments = '-s - 0 2 10' -split ' '; expectedResult = '0-2-4-6-8-10' -split ' '}
    ) {
        param([string]$command, [string[]]$arguments, [string[]]$expectedResult)

        Import-WslCommand $command

        & $command @arguments | Should -BeExactly $expectedResult
    }

    It "Enables calling commands with default arguments." -TestCases @(
        @{command = 'seq'; arguments = '0 10' -split ' '; expectedResult = '0-1-2-3-4-5-6-7-8-9-10'},
        @{command = 'seq'; arguments = '0 2 10' -split ' '; expectedResult = '0-2-4-6-8-10'},
        @{command = 'seq'; arguments = '-s : 0 2 10' -split ' '; expectedResult = '0:2:4:6:8:10'}
    ) {
        param([string]$command, [string[]]$arguments, [string]$expectedResult)

        Import-WslCommand $command

        Set-Variable WslDefaultParameterValues @{seq = "-s -"} -Scope Global

        & $command @arguments | Should -BeExactly $expectedResult

        Remove-Variable WslDefaultParameterValues -Scope Global
    }

    It "Enables calling commands that honor environment variables." -TestCases @(
        @{command = 'grep'; arguments = 'input' -split ' '; expectedResult = '1'}
    ) {
        param([string]$command, [string[]]$arguments, [string]$expectedResult)

        Import-WslCommand $command

        Set-Variable WslEnvironmentVariables @{GREP_OPTIONS = "-c"} -Scope Global

        "input" | & $command @arguments 2> $null | Should -BeExactly $expectedResult

        Remove-Variable WslEnvironmentVariables -Scope Global
    }

    It "Enables resolving Windows paths." -TestCases @(
        @{command = 'ls'; arguments = 'C:\Windows'; failureResult = 'ls: cannot access ''C:Windows''*'},
        @{command = 'ls'; arguments = 'C:\Windows'; failureResult = 'ls: cannot access ''C:/Windows''*'},
        @{command = 'ls'; arguments = 'C:\Win*'; failureResult = 'ls: cannot access ''C:Win*''*'},
        @{command = 'ls'; arguments = 'C:\Win*'; failureResult = 'ls: cannot access ''C:/Win*''*'},
        @{command = 'ls'; arguments = '/mnt/c/Program Files (x86)'; failureResult = 'ls: cannot access ''/mnt/c/Program''*'}
        @{command = 'ls'; arguments = '.\.github'; failureResult = 'ls: cannot access ''..github''*'},
        @{command = 'ls'; arguments = '.githu*'; failureResult = 'ls: cannot access ''.githu*''*'}
        @{command = 'ls'; arguments = '.githu?'; failureResult = 'ls: cannot access ''.githu?''*'}
        @{command = 'ls'; arguments = '.githu[abc]'; failureResult = 'ls: cannot access ''.githu[abc]''*'}
        @{command = 'ls'; arguments = '.githu[a/b]'; failureResult = 'Test-Path : Cannot retrieve the dynamic parameters for the cmdlet. The specified wildcard character pattern is not valid*'}
        @{command = 'ls'; arguments = '.githu[a\b]'; failureResult = 'Test-Path : Cannot retrieve the dynamic parameters for the cmdlet. The specified wildcard character pattern is not valid*'}
    ) {
        param([string]$command, [string[]]$arguments, [string]$failureResult)

        Import-WslCommand $command

        & $command @arguments 2>&1 | Should -Not -BeLike $failureResult
    }
}

Describe "Format-WslArgument" {
    It "Escapes special characters in <arg> when interactive is <interactive>." -TestCases @(
        @{arg = '/mnt/c/Windows'; interactive = $true; expectedResult = '/mnt/c/Windows'}
        @{arg = '/mnt/c/Windows'; interactive = $false; expectedResult = '/mnt/c/Windows'}
        @{arg = '/mnt/c/Windows '; interactive = $true; expectedResult = '/mnt/c/Windows'}
        @{arg = '/mnt/c/Windows '; interactive = $false; expectedResult = '/mnt/c/Windows'}
        @{arg = '/mnt/c/Program Files (x86)'; interactive = $true; expectedResult = '''/mnt/c/Program Files (x86)'''}
        @{arg = '/mnt/c/Program Files (x86)'; interactive = $false; expectedResult = '/mnt/c/Program\ Files\ \(x86\)'}
        @{arg = '/mnt/c/Program Files (x86) '; interactive = $true; expectedResult = '''/mnt/c/Program Files (x86)'''}
        @{arg = '/mnt/c/Program Files (x86) '; interactive = $false; expectedResult = '/mnt/c/Program\ Files\ \(x86\)'}
        @{arg = './Windows'; interactive = $true; expectedResult = './Windows'}
        @{arg = './Windows'; interactive = $false; expectedResult = './Windows'}
        @{arg = './Windows '; interactive = $true; expectedResult = './Windows'}
        @{arg = './Windows '; interactive = $false; expectedResult = './Windows'}
        @{arg = './Program Files (x86)'; interactive = $true; expectedResult = '''./Program Files (x86)'''}
        @{arg = './Program Files (x86)'; interactive = $false; expectedResult = './Program\ Files\ \(x86\)'}
        @{arg = './Program Files (x86) '; interactive = $true; expectedResult = '''./Program Files (x86)'''}
        @{arg = './Program Files (x86) '; interactive = $false; expectedResult = './Program\ Files\ \(x86\)'}
        @{arg = '~/.bashrc'; interactive = $true; expectedResult = '~/.bashrc'}
        @{arg = '~/.bashrc'; interactive = $false; expectedResult = '~/.bashrc'}
        @{arg = '~/.bashrc '; interactive = $true; expectedResult = '~/.bashrc'}
        @{arg = '~/.bashrc '; interactive = $false; expectedResult = '~/.bashrc'}
        @{arg = '/usr/share/bash-completion/bash_completion'; interactive = $true; expectedResult = '/usr/share/bash-completion/bash_completion'}
        @{arg = '/usr/share/bash-completion/bash_completion'; interactive = $false; expectedResult = '/usr/share/bash-completion/bash_completion'}
        @{arg = '/usr/share/bash-completion/bash_completion '; interactive = $true; expectedResult = '/usr/share/bash-completion/bash_completion'}
        @{arg = '/usr/share/bash-completion/bash_completion '; interactive = $false; expectedResult = '/usr/share/bash-completion/bash_completion'}
        @{arg = 's/;/\n/g'; interactive = $true; expectedResult = 's/`;/\n/g'}
        @{arg = 's/;/\n/g'; interactive = $false; expectedResult = 's/\;/\\n/g'}
        @{arg = '"s/;/\n/g"'; interactive = $true; expectedResult = '"s/;/\n/g"'}
        @{arg = '"s/;/\n/g"'; interactive = $false; expectedResult = '"s/;/\n/g"'}
        @{arg = '''s/;/\n/g'''; interactive = $true; expectedResult = '''s/;/\n/g'''}
        @{arg = '''s/;/\n/g'''; interactive = $false; expectedResult = '''s/;/\n/g'''}
        @{arg = '^(a|b)\w+\1'; interactive = $true; expectedResult = '^`(a`|b`)\w+\1'}
        @{arg = '^(a|b)\w+\1'; interactive = $false; expectedResult = '^\(a\|b\)\\w+\\1'}
        @{arg = '"^(a|b)\w+\1"'; interactive = $true; expectedResult = '"^(a|b)\w+\1"'}
        @{arg = '"^(a|b)\w+\1"'; interactive = $false; expectedResult = '"^(a|b)\w+\1"'}
        @{arg = '''^(a|b)\w+\1'''; interactive = $true; expectedResult = '''^(a|b)\w+\1'''}
        @{arg = '''^(a|b)\w+\1'''; interactive = $false; expectedResult = '''^(a|b)\w+\1'''}
        @{arg = '[aeiou]{2,}'; interactive = $true; expectedResult = '[aeiou]`{2`,`}'}
        @{arg = '[aeiou]{2,}'; interactive = $false; expectedResult = '[aeiou]\{2\,\}'}
        @{arg = '[[:digit:]]{2,}'; interactive = $true; expectedResult = '[[:digit:]]`{2`,`}'}
        @{arg = '[[:digit:]]{2,}'; interactive = $false; expectedResult = '[[:digit:]]\{2\,\}'}
        @{arg = '^foo(.*?)bar$'; interactive = $true; expectedResult = '^foo`(.*?`)bar$'}
        @{arg = '^foo(.*?)bar$'; interactive = $false; expectedResult = '^foo\(.*?\)bar$'}
        @{arg = '\^foo\.\*\?bar\$'; interactive = $true; expectedResult = '\^foo\.\*\?bar\$'}
        @{arg = '\^foo\.\*\?bar\$'; interactive = $false; expectedResult = '\\^foo\\.\\*\\?bar\\$'}
        @{arg = '\\\\\w'; interactive = $true; expectedResult = '\\\\\w'}
        @{arg = '\\\\\w'; interactive = $false; expectedResult = '\\\\\\\\\\w'}
        @{arg = '\\\\([^\\]+)'; interactive = $true; expectedResult = '\\\\`([^\\]+`)'}
        @{arg = '\\\\([^\\]+)'; interactive = $false; expectedResult = '\\\\\\\\\([^\\\\]+\)'}
        @{arg = '(\\\\[^\\]+)'; interactive = $true; expectedResult = '`(\\\\[^\\]+`)'}
        @{arg = '(\\\\[^\\]+)'; interactive = $false; expectedResult = '\(\\\\\\\\[^\\\\]+\)'}
        @{arg = '\(\)'; interactive = $true; expectedResult = '\`(\`)'}
        @{arg = '\(\)'; interactive = $false; expectedResult = '\\\(\\\)'}
        @{arg = '\a\b\c\d\e\f\g\h\i\j\k\l\m\n\o\p\q\r\s\t\u\v\w\x\y\z'; interactive = $true; expectedResult = '\a\b\c\d\e\f\g\h\i\j\k\l\m\n\o\p\q\r\s\t\u\v\w\x\y\z'}
        @{arg = '\a\b\c\d\e\f\g\h\i\j\k\l\m\n\o\p\q\r\s\t\u\v\w\x\y\z'; interactive = $false; expectedResult = '\\a\\b\\c\\d\\e\\f\\g\\h\\i\\j\\k\\l\\m\\n\\o\\p\\q\\r\\s\\t\\u\\v\\w\\x\\y\\z'}
        @{arg = '\A\B\C\D\E\F\G\H\I\J\K\L\M\N\O\P\Q\R\S\T\U\V\W\X\Y\Z'; interactive = $true; expectedResult = '\A\B\C\D\E\F\G\H\I\J\K\L\M\N\O\P\Q\R\S\T\U\V\W\X\Y\Z'}
        @{arg = '\A\B\C\D\E\F\G\H\I\J\K\L\M\N\O\P\Q\R\S\T\U\V\W\X\Y\Z'; interactive = $false; expectedResult = '\\A\\B\\C\\D\\E\\F\\G\\H\\I\\J\\K\\L\\M\\N\\O\\P\\Q\\R\\S\\T\\U\\V\\W\\X\\Y\\Z'}
        @{arg = '\0\1\2\3\4\5\6\7\8\9'; interactive = $true; expectedResult = '\0\1\2\3\4\5\6\7\8\9'}
        @{arg = '\0\1\2\3\4\5\6\7\8\9'; interactive = $false; expectedResult = '\\0\\1\\2\\3\\4\\5\\6\\7\\8\\9'}
    ) {
        param([string]$arg, [bool]$interactive, [string]$expectedResult)
        
        Format-WslArgument $arg $interactive | Should -BeExactly $expectedResult
    }
}