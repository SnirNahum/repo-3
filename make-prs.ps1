param(
  [Parameter(Mandatory=$true)][string]$RepoName,
  [Parameter(Mandatory=$true)][int]$PRs,
  [string]$ForkFrom = ""
)

function Die($msg) { Write-Error $msg; exit 1 }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die "Git is not installed." }
if (-not (Get-Command gh -ErrorAction SilentlyContinue))  { Die "GitHub CLI (gh) is not installed." }

try {
  gh auth status | Out-Null
} catch {
  Die "Run 'gh auth login' first."
}

$fullName = ""
if ($ForkFrom) {
  if ($ForkFrom -match "github\.com/([^/]+/[^/]+)") { $ForkFrom = $Matches[1] }
  Write-Host "Forking $ForkFrom ..."
  gh repo fork $ForkFrom --remote --clone --default-branch-only --confirm | Out-Null
  $fullName = (gh repo view --json nameWithOwner --jq .nameWithOwner)
  $localDir = (Split-Path -Leaf $fullName)
} else {
  $fullName = $RepoName
  Write-Host "Creating repo $fullName ..."
  gh repo create $fullName --private --disable-issues --confirm | Out-Null

  git clone "https://github.com/$fullName.git"
  $localDir = $RepoName
}

Set-Location $localDir

if (-not (Test-Path ".git")) { Die "Not a git repo here: $(Get-Location)" }

$defaultBranch = ""
try {
  $defaultBranch = (git symbolic-ref --short HEAD 2>$null)
} catch {}
if (-not $defaultBranch) {
  git checkout -b main
  "seed" | Out-File -Encoding utf8 .gitkeep
  git add .gitkeep
  git commit -m "chore: initial commit" | Out-Null
  git push -u origin main
  $defaultBranch = "main"
}

for ($i = 1; $i -le $PRs; $i++) {
  $branch = "feature/pr-$i"

  git checkout -b $branch
  "Auto content $(Get-Date -Format o) #$i" | Out-File -Encoding utf8 "file-$i.txt"
  Add-Content "file-$i.txt" ("`n" * (Get-Random -Minimum 1 -Maximum 4))
  git add "file-$i.txt"
  git commit -m "feat: add file $i" | Out-Null
  git push -u origin $branch

  gh pr create `
    --base $defaultBranch `
    --head $branch `
    --title "PR #$i - add file $i" `
    --body "Auto-generated PR $i for testing." `
    --draft | Out-Null

  Write-Host "Opened PR $i"
}

git checkout $defaultBranch | Out-Null
Write-Host "✅ Done. Created $PRs PRs in $fullName"
