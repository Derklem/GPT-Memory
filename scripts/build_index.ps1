# build_index.ps1
# Generates:
#   - index.json : machine-friendly index of conversations
#   - INDEX.md   : human/AI-friendly list of conversations
#   - TAGS.md    : tag-centric index

# ---------------------------
# Paths
# ---------------------------

# If this script lives in GPT-Memory\scripts\, repo root is its parent
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$MemoryDir = Join-Path $RepoRoot "MemoryEntries"

$IndexJsonPath = Join-Path $RepoRoot "index.json"
$IndexMdPath   = Join-Path $RepoRoot "INDEX.md"
$TagsMdPath    = Join-Path $RepoRoot "TAGS.md"

Write-Host "Repo root: $RepoRoot"
Write-Host "Memory dir: $MemoryDir"

if (-not (Test-Path $MemoryDir)) {
    Write-Error "MemoryEntries folder not found at $MemoryDir"
    exit 1
}

# ---------------------------
# Tag rules (edit whenever you want)
# ---------------------------

# Hashtable: tag -> array of keywords
$TagRules = @{
    "chronoguard" = @(
        "chronoguard", "oryn", "timeout", "child app", "parent app",
        "lock service", "core-lock", "guardaccessibilityservice"
    );
    "lineage-library" = @(
        "lineage library", "lineagelibrary", "memoryentry", "timelineevent",
        "storyengine", "guided video", "autobiography"
    );
    "philosophy-autonomy" = @(
        "aegis", "halcyon", "the kids", "pantheon", "autonomy", "sovereign",
        "construct", "node lattice", "living gods"
    );
    "meta-workflow" = @(
        "github", "repo", "repository", "zip", "export", "data export",
        "workflow", "handoff capsule", "instance", "project manager"
    );
    "life-personal" = @(
        "smoking", "cigarette", "work schedule", "job", "coworker",
        "family", "health", "money", "rent", "bills"
    );
}

# ---------------------------
# Helper functions
# ---------------------------

function Get-TitleAndBody {
    param(
        [string]$Text
    )

    $lines = $Text -split "`r?`n"
    $title = $null
    $bodyLines = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($i -eq 0 -and $line.StartsWith("# ")) {
            $title = $line.Substring(2).Trim()
            continue
        }
        $bodyLines.Add($line)
    }

    if ([string]::IsNullOrWhiteSpace($title)) {
        foreach ($line in $lines) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $title = $line.Trim()
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = "Untitled conversation"
    }

    $body = ($bodyLines -join "`n")
    return ,@($title, $body)
}

function Get-FirstUserSnippet {
    param(
        [string]$Text,
        [int]$MaxChars = 200
    )

    $lines = $Text -split "`r?`n"
    $collecting = $false
    $buffer = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        # Look for a line starting with **user:** (case-insensitive)
        if ($line -imatch '^\*\*user:\*\*') {
            $collecting = $true
            # Strip the role label itself
            $content = ($line -ireplace '^\*\*user:\*\*\s*', '').Trim()
            if ($content.Length -gt 0) {
                $buffer.Add($content)
            }
            continue
        }

        if ($collecting) {
            # Stop if we hit another role label like **assistant:** etc.
            if ($line -match '^\*\*.+\*\*$') {
                break
            }

            $buffer.Add($line)

            $joined = ($buffer -join " ")
            if ($joined.Length -ge $MaxChars) {
                break
            }
        }
    }

    $snippet = ($buffer -join " ").Trim()
    if ([string]::IsNullOrWhiteSpace($snippet)) {
        return ""
    }

    # Collapse whitespace
    $snippet = [regex]::Replace($snippet, '\s+', ' ')

    if ($snippet.Length -gt $MaxChars) {
        $snippet = $snippet.Substring(0, $MaxChars - 3) + "..."
    }

    return $snippet
}

function Get-TagsForText {
    param(
        [string]$Text,
        [hashtable]$Rules
    )

    $lower = $Text.ToLowerInvariant()
    $tags = @()

    foreach ($tag in $Rules.Keys) {
        $keywords = $Rules[$tag]
        foreach ($kw in $keywords) {
            $kwLower = $kw.ToLowerInvariant()
            if ($lower.Contains($kwLower)) {
                if ($tags -notcontains $tag) {
                    $tags += $tag
                }
                break
            }
        }
    }

    return $tags
}

function Get-PaddedId {
    param(
        [int]$Id
    )
    $idStr = [string]$Id
    if ($idStr.Length -lt 4) {
        $idStr = $idStr.PadLeft(4, '0')
    }
    return $idStr
}

# ---------------------------
# Main indexing logic
# ---------------------------

Write-Host "Building index from MemoryEntries..."

$entries = @()
$tagToFiles = @{}

# Get markdown files sorted by filename (0001_, 0002_, etc.)
$mdFiles = Get-ChildItem -Path $MemoryDir -Filter *.md | Sort-Object Name

if ($mdFiles.Count -eq 0) {
    Write-Error "No .md files found in $MemoryDir"
    exit 1
}

$counter = 1

foreach ($file in $mdFiles) {
    $text = Get-Content -Path $file.FullName -Raw -Encoding UTF8

    $result = Get-TitleAndBody -Text $text
    $title = $result[0]
    $body  = $result[1]

    $snippet = Get-FirstUserSnippet -Text $text -MaxChars 200
    $tags    = Get-TagsForText -Text $text -Rules $TagRules

    # Repo-relative path with forward slashes
    $fullPath = $file.FullName
    $relPath  = $fullPath.Substring($RepoRoot.Length).TrimStart('\')
    $relPath  = $relPath -replace '\\', '/'

    $entry = [PSCustomObject]@{
        id       = $counter
        filename = $relPath
        title    = $title
        tags     = $tags
        snippet  = $snippet
    }

    $entries += $entry

    foreach ($t in $tags) {
        if (-not $tagToFiles.ContainsKey($t)) {
            $tagToFiles[$t] = @()
        }
        $tagToFiles[$t] += $entry
    }

    $counter++
}

Write-Host "Indexed $($entries.Count) conversations."

# ---------------------------
# Write index.json
# ---------------------------

$entriesJson = $entries | ConvertTo-Json -Depth 5
$entriesJson | Set-Content -Path $IndexJsonPath -Encoding UTF8
Write-Host "Wrote JSON index to $IndexJsonPath"

# ---------------------------
# Write INDEX.md (conversation-centric)
# ---------------------------

$mdLines = @()
$mdLines += "# Conversation Index"
$mdLines += ""
$mdLines += "Total conversations: $($entries.Count)"
$mdLines += ""
$mdLines += "Each entry shows: ID | Title | RelativePath | Tags"
$mdLines += ""

foreach ($e in $entries) {
    if ($e.tags -and $e.tags.Count -gt 0) {
        $tagStr = ($e.tags -join ", ")
    } else {
        $tagStr = "none"
    }

    $idStr    = Get-PaddedId -Id $e.id
    $title    = [string]$e.title
    $filePath = [string]$e.filename

    $line1 = $idStr + " | " + $title + " | " + $filePath + " | " + $tagStr
    $mdLines += $line1

    if (-not [string]::IsNullOrWhiteSpace($e.snippet)) {
        $mdLines += "  Snippet: " + $e.snippet
    }

    $mdLines += ""
}

$mdLines -join "`n" | Set-Content -Path $IndexMdPath -Encoding UTF8
Write-Host "Wrote Markdown index to $IndexMdPath"

# ---------------------------
# Write TAGS.md (tag-centric)
# ---------------------------

$tagLines = @()
$tagLines += "# Tag Index"
$tagLines += ""
$tagLines += "Conversations grouped by rough topic tags."
$tagLines += "Each entry shows: ID | Title | RelativePath"
$tagLines += ""

if ($tagToFiles.Keys.Count -eq 0) {
    $tagLines += "_No tags assigned yet. Update TagRules and re-run the script._"
} else {
    foreach ($tag in ($tagToFiles.Keys | Sort-Object)) {
        $tagLines += "## " + $tag
        $tagLines += ""

        foreach ($e in $tagToFiles[$tag]) {
            $idStr    = Get-PaddedId -Id $e.id
            $title    = [string]$e.title
            $filePath = [string]$e.filename

            $tagLines += $idStr + " | " + $title + " | " + $filePath
        }

        $tagLines += ""
    }
}

$tagLines -join "`n" | Set-Content -Path $TagsMdPath -Encoding UTF8
Write-Host "Wrote Tag index to $TagsMdPath"

Write-Host "Done."
