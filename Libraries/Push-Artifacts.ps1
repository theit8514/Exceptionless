$base_dir = Resolve-Path ".\"   
$artifactsDir = "$base_dir\artifacts"
$sourceDir = "$base_dir\Source"

If ($env:APPVEYOR_PULL_REQUEST_NUMBER -ne $null) {
    Write-Host "Artifacts will not be created for pull requests."
    Return
}

Write-Host "Cloning repository into $($artifactsDir)..."
git clone "$env:BUILD_REPO_URL" "$artifactsDir" -q 2>&1 | %{ "$_" }

If ($LastExitCode -ne 0) {
    Write-Error "An error occurred while cloning the repository."
    Return $LastExitCode
}

Push-Location $artifactsDir

git fetch --all -f -q 2>&1 | %{ "$_" }
$branches = (git branch -r) 2> $null
If (($branches.Replace(" ", "").Split([environment]::NewLine) -contains "origin/$($env:APPVEYOR_REPO_BRANCH)") -eq $True) {
    Write-Host "Checking out branch: $env:APPVEYOR_REPO_BRANCH"
    git checkout "$env:APPVEYOR_REPO_BRANCH" -f -q 2>&1 | %{ "$_" }
} else {
    Write-Host "Checking out new branch: $env:APPVEYOR_REPO_BRANCH"
    git checkout -b "$env:APPVEYOR_REPO_BRANCH" -q 2>&1 | %{ "$_" }
}

If ($LastExitCode -ne 0) {
    Write-Error "An error occurred while changing to branch: $env:APPVEYOR_REPO_BRANCH"
    Return $LastExitCode
}

Write-Host "Removing existing files..."
git rm -r * -q 2>&1 | %{ "$_" }

Write-Host "Copying build artifacts..."
ROBOCOPY "$sourceDir\Api" "$artifactsDir" /XD "$sourceDir\Api\obj" "$sourceDir\Api\App_Data" /S /XF "*.nuspec" "*.settings" "*.cs" "packages.config" "*.csproj" "*.user" "*.suo" "*.xsd" "*.ide" /NFL /NDL /NJH /NJS /nc /ns /np

Write-Host "Copying CloseInactiveSession job..."
ROBOCOPY "$sourceDir\Jobs\CloseInactiveSession\bin\Release" "$artifactsDir\App_Data\jobs\continuous\CloseInactiveSession" /S /NFL /NDL /NJH /NJS /nc /ns /np
Write-Host "Copying DailySummary job..."
ROBOCOPY "$sourceDir\Jobs\DailySummary\bin\Release" "$artifactsDir\App_Data\jobs\continuous\DailySummary" /S /NFL /NDL /NJH /NJS /nc /ns /np
Write-Host "Copying DownloadGeoIPDatabase job..."
ROBOCOPY "$sourceDir\Jobs\DownloadGeoIPDatabase\bin\Release" "$artifactsDir\App_Data\jobs\continuous\DownloadGeoIPDatabase" /S /NFL /NDL /NJH /NJS /nc /ns /np
Write-Host "Copying EventNotification job..."
ROBOCOPY "$sourceDir\Jobs\EventNotification\bin\Release" "$artifactsDir\App_Data\jobs\continuous\EventNotification" /S /NFL /NDL /NJH /NJS /nc /ns /np
Write-Host "Copying EventPost job..."
ROBOCOPY "$sourceDir\Jobs\EventPost\bin\Release" "$artifactsDir\App_Data\jobs\continuous\EventPost" /S /NFL /NDL /NJH /NJS /nc /ns /np
Write-Host "Copying EventUserDescription job..."
ROBOCOPY "$sourceDir\Jobs\EventUserDescription\bin\Release" "$artifactsDir\App_Data\jobs\continuous\EventUserDescription" /S /NFL /NDL /NJH /NJS /nc /ns /np
Write-Host "Copying MailMessage job..."
ROBOCOPY "$sourceDir\Jobs\MailMessage\bin\Release" "$artifactsDir\App_Data\jobs\continuous\MailMessage" /S /NFL /NDL /NJH /NJS /nc /ns /np
Write-Host "Copying RetentionLimit job..."
ROBOCOPY "$sourceDir\Jobs\RetentionLimit\bin\Release" "$artifactsDir\App_Data\jobs\continuous\RetentionLimit" /S /NFL /NDL /NJH /NJS /nc /ns /np
Write-Host "Copying WebHook job..."
ROBOCOPY "$sourceDir\Jobs\WebHook\bin\Release" "$artifactsDir\App_Data\jobs\continuous\WebHook" /S /NFL /NDL /NJH /NJS /nc /ns /np
Write-Host "Copying WorkItem job..."
ROBOCOPY "$sourceDir\Jobs\WorkItem\bin\Release" "$artifactsDir\App_Data\jobs\continuous\WorkItem" /S /NFL /NDL /NJH /NJS /nc /ns /np

Write-Host "Committing the latest changes..."
git add * 2>&1 | %{ "$_" }
git commit -a -m "Build: $env:APPVEYOR_BUILD_VERSION Author: $env:APPVEYOR_REPO_COMMIT_AUTHOR $($env:APPVEYOR_REPO_NAME)@$($env:APPVEYOR_REPO_COMMIT)" -q 2>&1 | %{ "$_" }
git push origin "$env:APPVEYOR_REPO_BRANCH" -q 2>&1 | %{ "$_" }

If ($LastExitCode -ne 0) {
    Write-Error "An error occurred while committing the latest changes."
    Return $LastExitCode
} Else {
    Write-Host "Finished committing the latest changes."
}

Pop-Location