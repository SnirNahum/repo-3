param(
  [Parameter(Mandatory=$true)][int]$Count
)

function Ensure-Branch {
  param([string]$Base = "main", [string]$From = "main")

  $exists = (git branch -a | Select-String -SimpleMatch "remotes/origin/$Base") -ne $null
  if (-not $exists) {
    git checkout $From
    git pull --ff-only origin $From 2>$null
    git checkout -b $Base $From
    git push -u origin $Base
  } else {
    git checkout $Base
    git pull --ff-only origin $Base 2>$null
  }
}

function New-PRSet {
  param(
    [Parameter(Mandatory=$true)][string]$Base,
    [Parameter(Mandatory=$true)][int]$Count
  )

  Ensure-Branch -Base $Base -From "main"

  $hasGh = (Get-Command gh -ErrorAction SilentlyContinue) -ne $null
  if (-not $hasGh) {
    Write-Error "❌ GitHub CLI (gh) is not installed or not in PATH."
    return
  }

  for ($i = 1; $i -le $Count; $i++) {
    $branch = "feature/$Base-pr-$i"
    $fileName = "file-$Base-$i.txt"

    try {
      git checkout -b $branch $Base
      "auto content for $Base #$i $(Get-Date -Format o)" | Out-File -Encoding utf8 $fileName
      git add $fileName
      git commit -m "feat($Base): add file $i"
      git push -u origin $branch --force
      git checkout $Base

      Write-Host "📦 Branch pushed: $branch"

      $prUrl = gh pr create `
        --base $Base `
        --head $branch `
        --title "$Base PR #$i - add file $i" `
        --body "Auto-generated PR $i targeting $Base." `
        --draft

      if ($prUrl) {
        Write-Host "✅ PR created: $prUrl"
      } else {
        Write-Warning "⚠️ No PR URL returned for $branch"
      }

    } catch {
      Write-Error "❌ Error creating PR for $branch: $_"
    }
  }

  Write-Host "`n🎉 All done. $Count PR(s) processed for base '$Base'." -ForegroundColor Green
}

# Run it
New-PRSet -Base "base-prs" -Count $Count
