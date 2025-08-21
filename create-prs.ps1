name: Create PRs

on:
  workflow_dispatch:  

jobs:
  generate-prs:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Install GitHub CLI
        run: |
          sudo apt update
          sudo apt install gh -y

      - name: Run PowerShell script
        shell: pwsh
        run: |
          ./create-prs.ps1 -RepoName "${{ github.repository }}" -PRs 5