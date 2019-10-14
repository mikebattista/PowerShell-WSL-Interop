Import-Module .\WslInterop.psd1

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
        @{arg = 's/;/\n/g'; interactive = $true; expectedResult = 's/`;/\\n/g'}
        @{arg = 's/;/\n/g'; interactive = $false; expectedResult = 's/\;/\\n/g'}
        @{arg = '^(a|b).*'; interactive = $true; expectedResult = '^`(a`|b`).*'}
        @{arg = '^(a|b).*'; interactive = $false; expectedResult = '^\(a\|b\).*'}
        @{arg = '\a\b\c\d\e\f\g\h\i\j\k\l\m\n\o\p\q\r\s\t\u\v\w\x\y\z'; interactive = $true; expectedResult = '\\a\\b\c\d\\e\\f\g\h\i\j\k\l\m\\n\o\p\q\\r\s\\t\u\\v\w\x\y\z'}
        @{arg = '\a\b\c\d\e\f\g\h\i\j\k\l\m\n\o\p\q\r\s\t\u\v\w\x\y\z'; interactive = $false; expectedResult = '\\a\\b\c\d\\e\\f\g\h\i\j\k\l\m\\n\o\p\q\\r\s\\t\u\\v\w\x\y\z'}
        @{arg = '\A\B\C\D\E\F\G\H\I\J\K\L\M\N\O\P\Q\R\S\T\U\V\W\X\Y\Z'; interactive = $true; expectedResult = '\\A\\B\C\D\\E\\F\G\H\I\J\K\L\M\\N\O\P\Q\\R\S\\T\U\\V\W\X\Y\Z'}
        @{arg = '\A\B\C\D\E\F\G\H\I\J\K\L\M\N\O\P\Q\R\S\T\U\V\W\X\Y\Z'; interactive = $false; expectedResult = '\\A\\B\C\D\\E\\F\G\H\I\J\K\L\M\\N\O\P\Q\\R\S\\T\U\\V\W\X\Y\Z'}
        @{arg = '\0\1\2\3\4\5\6\7\8\9'; interactive = $true; expectedResult = '\0\1\2\3\4\5\6\7\8\9'}
        @{arg = '\0\1\2\3\4\5\6\7\8\9'; interactive = $false; expectedResult = '\0\1\2\3\4\5\6\7\8\9'}
    ) {
        param([string]$arg, [bool]$interactive, [string]$expectedResult)
        
        Format-WslArgument $arg $interactive | Should -BeExactly $expectedResult
    }
}