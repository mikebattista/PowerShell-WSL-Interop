$module = Test-ModuleManifest .\*.psd1
$moduleName = $module.Name
$moduleVersion = $module.Version.ToString()
$modulePath = "$(($Env:PSModulePath -split ';')[0])\$moduleName\$moduleVersion"

Remove-Item $modulePath -Recurse -Force -ErrorAction Ignore 
New-Item $modulePath -ItemType Directory -Force | Out-Null
Copy-Item .\* $modulePath -Recurse -Exclude .github, *.Publish.ps1, *.Tests.ps1

Publish-Module -Name $moduleName -RequiredVersion $moduleVersion -NuGetApiKey $args[0] -Confirm