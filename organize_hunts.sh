#!/bin/bash
# Organize and commit hunts systematically

cd /home/iyke/coding/security-research

# Function to commit a hunt
commit_hunt() {
    local hunt_name=$1
    local description=$2
    
    echo "=== Committing $hunt_name ==="
    git add hunts/$hunt_name/
    git commit -m "feat(hunts): Add $hunt_name hunt

$description

Status: Documented in hunt directory
Files: $(find hunts/$hunt_name -type f | wc -l) files committed" || echo "Already committed or no changes"
}

# Organize metadata first
git add hunts/_meta/
git commit -m "chore(hunts): Organize hunt metadata and session summaries

Moved all hunt session summaries and metadata to _meta/:
- Master summaries
- Verification status
- Target lists
- Session prompts" || echo "Metadata already committed"

echo "Hunts organized and ready for individual commits"
