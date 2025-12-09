param(
    # Path to the conversations.json file from your ChatGPT export
    [string]$ConversationsPath
)

# ---------------------------
# Resolve repo + MemoryEntries
# ---------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$MemoryDir = Join-Path $RepoRoot "MemoryEntries"

Write-Host "Repo root: $RepoRoot"
Write-Host "Memory dir: $MemoryDir"
Write-Host "Conversations JSON: $ConversationsPath"

if (-not (Test-Path $ConversationsPath)) {
    Write-Error "conversations.json not found at $ConversationsPath"
    exit 1
}

if (-not (Test-Path $MemoryDir)) {
    New-Item -ItemType Directory -Path $MemoryDir | Out-Null
}

# Clear old markdowns so we start clean
Get-ChildItem -Path $MemoryDir -Filter *.md -ErrorAction SilentlyContinue | Remove-Item -Force

# ---------------------------
# Load JSON
# ---------------------------

$jsonText = Get-Content -Path $ConversationsPath -Raw -Encoding UTF8
$jsonObj  = $jsonText | ConvertFrom-Json

# Some exports are an array, some are { conversations: [...] }
if ($jsonObj.conversations) {
    $convs = $jsonObj.conversations
} else {
    $convs = $jsonObj
}

if (-not $convs) {
    Write-Error "No conversations found in JSON (neither top-level array nor .conversations)."
    exit 1
}

# ---------------------------
# Helper: safe file name
# ---------------------------

function Get-SafeTitle {
    param([string]$Title)

    if ([string]::IsNullOrWhiteSpace($Title)) {
        return "Conversation"
    }

    $safe = ($Title -replace '[^\w\- ]', '').Trim()
    if ([string]::IsNullOrWhiteSpace($safe)) {
        $safe = "Conversation"
    }

    if ($safe.Length -gt 40) {
        $safe = $safe.Substring(0, 40)
    }

    return $safe
}

# ---------------------------
# Build markdown files (raw JSON for now)
# ---------------------------

$index = 1
$nl = [Environment]::NewLine

foreach ($conv in $convs) {
    $title = $conv.title
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = "Conversation $index"
    }

    $safeTitle = Get-SafeTitle -Title $title
    $fileName  = ("{0:0000}_{1}.md" -f $index, ($safeTitle -replace ' ', '_'))
    $filePath  = Join-Path $MemoryDir $fileName

    $lines = @()
    $lines += "# $title"
    $lines += ""

    # Try to include created time if present
    if ($conv.create_time) {
        try {
            $dt = [DateTimeOffset]::FromUnixTimeSeconds([int64]$conv.create_time).ToLocalTime()
            $lines += "_Created: $dt_"
            $lines += ""
        } catch {
            # ignore if it fails
        }
    }

    $lines += "```json"
    $lines += ($conv | ConvertTo-Json -Depth 12)
    $lines += "```"
    $lines += ""

    $text = $lines -join $nl
    Set-Content -Path $filePath -Value $text -Encoding UTF8

    Write-Host "Wrote $fileName"
    $index++
}

Write-Host "Done. Wrote $($index - 1) markdown conversations into $MemoryDir."
