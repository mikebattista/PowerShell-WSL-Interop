$module = Test-ModuleManifest .\*.psd1
$moduleName = $module.Name
$moduleVersion = $module.Version.ToString()
$modulePath = "$Env:TEMP\$(New-Guid)\$moduleName"

[version]::new($moduleVersion).CompareTo([version]::new((Find-PSResource $moduleName).Version)) | Should -Be 1

New-Item $modulePath -ItemType Directory -Force | Out-Null
Copy-Item .\* $modulePath -Recurse -Exclude .github, *.Publish.ps1, *.Tests.ps1
Get-ChildItem $modulePath -Force | Select-Object -ExpandProperty Name | Should -BeExactly "LICENSE", "README.md", "WslInterop.psd1", "WslInterop.psm1"

Publish-PSResource -Path $modulePath -Repository PSGallery -ApiKey $args[0] -Confirm

Remove-Item $modulePath -Recurse -Force -ErrorAction Ignore