param(
    [string]$Query,
    [string]$Tag,
    [int]$Id,
    [switch]$Open,
    [switch]$Interactive,
    [int]$Limit = 20
)

$repoRoot  = (Get-Location).Path
$memoryDir = Join-Path $repoRoot 'MemoryEntries'
$indexPath = Join-Path $repoRoot 'index.json'

Write-Host "GPT-Memory Navigator"
Write-Host "---------------------"
Write-Host ""
Write-Host "Examples:"
Write-Host "  # Search content for a word or phrase"
Write-Host "  .\scripts\Invoke-GptMemoryNavigator.ps1 -Query 'flask-cors' -Limit 15"
Write-Host ""
Write-Host "  # Search by tag from index.json"
Write-Host "  .\scripts\Invoke-GptMemoryNavigator.ps1 -Tag 'Obelisk-3' -Limit 30"
Write-Host ""
Write-Host "  # Open a specific entry by Id"
Write-Host "  .\scripts\Invoke-GptMemoryNavigator.ps1 -Id 185 -Open"
Write-Host ""

# --- Load index.json (if present) and build filename -> (Id,Title,Filename) map ---

$hasIndex    = Test-Path $indexPath
$index       = $null
$fileInfoMap = @{}

if ($hasIndex) {
    try {
        $index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json

        foreach ($entry in $index) {
            # Example filename in index.json:
            # "MemoryEntries/0185_Halcyon_Autonomy_Unlock_Plan.md"
            $keyWithDir = $entry.filename.ToLower()
            $leaf       = [System.IO.Path]::GetFileName($entry.filename).ToLower()

            $info = [pscustomobject]@{
                Id       = $entry.id
                Title    = $entry.title
                Filename = $entry.filename
            }

            $fileInfoMap[$keyWithDir] = $info

            if (-not $fileInfoMap.ContainsKey($leaf)) {
                $fileInfoMap[$leaf] = $info
            }
        }
    }
    catch {
        Write-Warning "Could not read index.json: $_"
    }
} else {
    Write-Host "index.json not found. Id and tag features will be limited." -ForegroundColor Yellow
}

$results = @()

# --- Content search (--Query) ---

if ($Query) {
    if (-not (Test-Path $memoryDir)) {
        Write-Error "MemoryEntries folder not found at $memoryDir"
    }
    else {
        Write-Host "Searching for '$Query' in $memoryDir\*.md ..."

        $files = Get-ChildItem -Path $memoryDir -Filter *.md

        foreach ($f in $files) {
            $hits = Select-String -Path $f.FullName -Pattern $Query -SimpleMatch

            foreach ($hit in $hits) {
                # Try to map this file back to index.json
                $lookupWithDir = ("MemoryEntries/" + $f.Name).ToLower()
                $lookupLeaf    = $f.Name.ToLower()

                $info = $null
                if ($fileInfoMap.ContainsKey($lookupWithDir)) {
                    $info = $fileInfoMap[$lookupWithDir]
                }
                elseif ($fileInfoMap.ContainsKey($lookupLeaf)) {
                    $info = $fileInfoMap[$lookupLeaf]
                }

                $results += [pscustomobject]@{
                    Id         = if ($info) { $info.Id } else { -1 }
                    Title      = if ($info) { $info.Title } else { $f.Name }
                    FileName   = $f.Name
                    LineNumber = $hit.LineNumber
                    Snippet    = $hit.Line.Trim()
                }
            }
        }

        if ($results.Count -eq 0) {
            Write-Host "No matches found."
        }
        else {
            $shown = $results | Select-Object -First $Limit
            $shown | Format-Table Id,Title,Snippet -AutoSize

            if ($Interactive) {
                Write-Host ""
                Write-Host "Interactive mode: choose a result to open."
                for ($i = 0; $i -lt $shown.Count; $i++) {
                    $r = $shown[$i]
                    Write-Host ("[{0}] Id={1} Title={2}" -f $i, $r.Id, $r.Title)
                }

                while ($true) {
                    $choice = Read-Host "Enter number to open (blank to quit)"
                    if ([string]::IsNullOrWhiteSpace($choice)) { break }

                    [int]$n = 0
                    if (-not [int]::TryParse($choice, [ref]$n)) {
                        Write-Host "Not a number. Try again."
                        continue
                    }

                    if ($n -lt 0 -or $n -ge $shown.Count) {
                        Write-Host "Out of range. Try again."
                        continue
                    }

                    $selected  = $shown[$n]
                    $pathToOpen = Join-Path $memoryDir $selected.FileName

                    if (Test-Path $pathToOpen) {
                        Write-Host "Opening $pathToOpen ..."
                        Invoke-Item $pathToOpen
                    }
                    else {
                        Write-Warning "File not found: $pathToOpen"
                    }
                }
            }
        }
    }
}

# --- Tag search (--Tag) ---

if ($Tag) {
    if (-not $hasIndex -or -not $index) {
        Write-Host "index.json missing; cannot search by tag." -ForegroundColor Yellow
    }
    else {
        Write-Host "Searching index.json for tag '$Tag' ..."

        # Note: tags are currently empty in index.json, so this will likely return nothing for now.
        $tagMatches = $index | Where-Object { $_.tags.$Tag }

        if (-not $tagMatches -or $tagMatches.Count -eq 0) {
            Write-Host "No entries found with tag '$Tag'."
        }
        else {
            $tagMatches |
                Select-Object -First $Limit `
                    @{Name='Id';Expression={$_.id}} `
                    @{Name='Title';Expression={$_.title}} `
                    @{Name='File';Expression={$_.filename}} |
                Format-Table -AutoSize
        }
    }
}

# --- Open by Id (--Id) ---

if ($Id) {
    if (-not $hasIndex -or -not $index) {
        Write-Host "index.json missing; cannot open by Id." -ForegroundColor Yellow
    }
    else {
        Write-Host "Looking up entry with Id = $Id ..."
        $entry = $index | Where-Object { $_.id -eq $Id } | Select-Object -First 1

        if (-not $entry) {
            Write-Host "No entry with Id $Id found in index.json."
        }
        else {
            # IMPORTANT: filename already includes 'MemoryEntries/...'
            $filePath = Join-Path $repoRoot $entry.filename

            if (-not (Test-Path $filePath)) {
                Write-Host "File not found: $filePath"
            }
            else {
                if ($Open) {
                    Write-Host "Opening $filePath ..."
                    Invoke-Item $filePath
                }
                else {
                    Write-Host "Preview of $filePath"
                    Get-Content -Path $filePath -TotalCount 80
                }
            }
        }
    }
}

if (-not $Query -and -not $Tag -and -not $Id) {
    Write-Host ""
    Write-Host "No action parameters supplied. Use -Query, -Tag, or -Id."
}
