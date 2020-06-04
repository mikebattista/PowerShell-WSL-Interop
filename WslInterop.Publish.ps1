$module = Test-ModuleManifest .\*.psd1
$moduleName = $module.Name
$moduleVersion = $module.Version.ToString()
$modulePath = "$(($Env:PSModulePath -split ';')[0])\$moduleName\$moduleVersion"

[version]::new($moduleVersion).CompareTo([version]::new((Find-Module $moduleName).Version)) | Should -Be 1

Remove-Item $modulePath -Recurse -Force -ErrorAction Ignore 
New-Item $modulePath -ItemType Directory -Force | Out-Null
Copy-Item .\* $modulePath -Recurse -Exclude .github, *.Publish.ps1, *.Tests.ps1
Get-ChildItem $modulePath -Force | Select-Object -ExpandProperty Name | Should -BeExactly "LICENSE", "README.md", "WslInterop.psd1", "WslInterop.psm1"

Publish-Module -Name $moduleName -RequiredVersion $moduleVersion -NuGetApiKey $args[0] -Confirm