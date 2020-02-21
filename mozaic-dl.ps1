# outputDir is where the downloaded files will be saved.
$outputDir = ".\patches"

# stateFile is used to track already downloaded patches to avoid needless repetition.
$stateFile = "downloadedPatches.txt"

# this endpoint is scheduled to leave alpha on 2020-03-01
# at that time tne new endpoint is v1
# $apiEndpoint = "https://patchstorage.com/api/v1"
$apiEndpoint = "https://patchstorage.com/api/alpha"

# this is the id for the mozaic platform.
# it's a magic integer for the sake of keeping this script simple,
# but can be found with this API request or opening the link:
# irm https://patchstorage.com/api/alpha/platforms?search=mozaic
$mozaicId = 3341

# The API default value is 10, and has a limit of 100.
# Anything higher than 100 throws a 400 error.
$patchesPerRequest = 25

# This is a failsafe to avoid runaway request loops.
# This may not be needed but belts and suspenders...
$maxPages = 30

# start at the first page. This will be used to iterate the requests.
$page = 1

# setup the working files
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -ErrorAction Stop
}

if (Test-Path -Path $stateFile -PathType Leaf) {
    $priorDownloads = Get-Content $stateFile
}
else {
    New-Item -ItemType File -Path $stateFile -ErrorAction Stop
    $priorDownloads = @()
}

# initialize the state
$allPatchesFound = $false
$patchesFound = @()

while (-not ($allPatchesFound) -and ($page -le $maxPages)) {
    $uri = "{0}/patches/?platforms={1}&per_page={2}&page={3}" -f $apiEndpoint, $mozaicId, $patchesPerRequest, $page
    Write-Output "[Query #$page] Performing API query $uri"
    $req = Invoke-RestMethod -uri $uri -ErrorAction Stop

    # append the patches found in the current request
    $patchesFound += $req

    # once the query returns fewer results than the patchesPerRequest limit
    if ($req.length -lt $patchesPerRequest) {
        Write-Output "[Query End] Last query returned $($req.length) results, which is less than the page max of $patchesPerRequest"
        $allPatchesFound = $true
    }

    # increment the page index
    $page++
}

foreach ($patch in $patchesFound) {

    $patchInfo = Invoke-RestMethod -uri $patch.self
    $uri = $patchInfo.files.url
    $name = $patchInfo.files.filename
    $outFile = "$outputDir\$name"

    if ($name -notin $priorDownloads) {
        Write-Output "[$name] downloading from $uri to $outFile"
        Invoke-RestMethod -Uri $uri -OutFile $outFile -ErrorAction Stop
        $name | Out-File -FilePath $stateFile -Append -Force 
    }
    else {
        Write-Output "[$name] found in $stateFile as a prior download.  Skipping."
    }

}