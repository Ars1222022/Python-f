# =============================================
# SETUP GITHUB FÖR INSIDER THREAT DETECTION
# =============================================
# Detta skript:
# 1. Förklarar vad Git LFS är
# 2. Frågar efter GitHub-användarnamn och branch-namn
# 3. Skapar .gitignore
# 4. Installerar och konfigurerar Git LFS (om inte redan installerat)
# 5. Spårar .pkl-filer med Git LFS
# 6. Lägger till alla filer och pushar till GitHub
# =============================================

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "🚀 SETUP GITHUB FÖR INSIDER THREAT DETECTION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# =============================================
# DEL 1: FÖRKLARING AV GIT LFS
# =============================================
Write-Host "`n📚 DEL 1: VAD ÄR GIT LFS?" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Gray
Write-Host @"
Git LFS (Large File Storage) är ett tillägg till Git som hanterar stora filer.

┌─────────────────────────────────────────────────────────────────┐
│  PROBLEM: Vanlig Git klarar inte filer över 100 MB              │
│  LÖSNING: Git LFS sparar stora filer separat och länkar till dem│
└─────────────────────────────────────────────────────────────────┘

Vanlig Git:
    Du lägger till en stor fil → Git sparar hela filen i historiken
    → Repository blir massivt → Långsamt att klona

Git LFS:
    Du lägger till en stor fil → Git sparar en LÄNK till filen
    → Repository förblir litet → Snabbt att klona

I DITT PROJEKT:
    ✅ random_forest_model.pkl (786 KB) → Git LFS
    ✅ scaler.pkl (1.5 KB) → Git LFS
"@

Read-Host "`n🔹 Tryck Enter för att fortsätta..."

# =============================================
# DEL 2: FRÅGA EFTER GITHUB-ANVÄNDARNAMN OCH BRANCH
# =============================================
Write-Host "`n📚 DEL 2: KONFIGURATION" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

$githubUsername = Read-Host "🔑 Ange ditt GitHub-användarnamn"

if (-not $githubUsername) {
    Write-Host "❌ Inget användarnamn angivet. Avbryter..." -ForegroundColor Red
    exit 1
}

Write-Host "`n📌 Välj branch-namn:" -ForegroundColor Yellow
Write-Host "   1. main (ny standard, rekommenderas)"
Write-Host "   2. master (gammal standard)"
$branchChoice = Read-Host "🔢 Ange siffra (1-2)"

if ($branchChoice -eq "1") {
    $branchName = "main"
} else {
    $branchName = "master"
}

$repoName = "insider-threat-detection"
$repoUrl = "https://github.com/$githubUsername/$repoName.git"

Write-Host "`n✅ GitHub-användare: $githubUsername" -ForegroundColor Green
Write-Host "✅ Branch-namn: $branchName" -ForegroundColor Green
Write-Host "✅ Repository: $repoUrl" -ForegroundColor Green

Read-Host "`n🔹 Tryck Enter för att fortsätta..."

# =============================================
# DEL 3: INITIERA GIT
# =============================================
Write-Host "`n📚 DEL 3: INITIERAR GIT" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

# Kontrollera om Git redan är initierat
if (Test-Path ".git") {
    Write-Host "⚠️ Git är redan initierat i denna mapp." -ForegroundColor Yellow
    $reinit = Read-Host "🔸 Vill du rensa och börja om? (j/n)"
    if ($reinit -eq "j") {
        Remove-Item -Recurse -Force ".git"
        git init
        Write-Host "✅ Git initierat på nytt!" -ForegroundColor Green
    } else {
        Write-Host "✅ Behåller befintlig Git-konfiguration." -ForegroundColor Green
    }
} else {
    git init
    Write-Host "✅ Git initierat!" -ForegroundColor Green
}

# =============================================
# DEL 4: SKAPA .GITIGNORE
# =============================================
Write-Host "`n📚 DEL 4: SKAPAR .GITIGNORE" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

$gitignoreContent = @"
# Hemligheter (ladda ALDRIG upp!)
*.txt
secrets*
*password*
*api*
*key*
*slack*
*groq*

# Temporära filer
__pycache__/
*.pyc
*.pyo
.DS_Store
Thumbs.db
*.tmp

# Databricks
dbutils/
secrets/

# Manifest-fil (behövs inte)
manifest.mf

# Stora mediafiler (valfritt – kommentera bort om du vill ha med dem)
# *.mp4
# *.m4a
"@

# Kontrollera om .gitignore redan finns
if (Test-Path ".gitignore") {
    Write-Host "⚠️ .gitignore finns redan." -ForegroundColor Yellow
    $overwrite = Read-Host "🔸 Vill du ersätta den? (j/n)"
    if ($overwrite -eq "j") {
        $gitignoreContent | Out-File -FilePath ".gitignore" -Encoding utf8
        Write-Host "✅ .gitignore ersatt!" -ForegroundColor Green
    } else {
        Write-Host "✅ Behåller befintlig .gitignore." -ForegroundColor Green
    }
} else {
    $gitignoreContent | Out-File -FilePath ".gitignore" -Encoding utf8
    Write-Host "✅ .gitignore skapad!" -ForegroundColor Green
}

# =============================================
# DEL 5: INSTALLERA OCH KONFIGURERA GIT LFS
# =============================================
Write-Host "`n📚 DEL 5: GIT LFS (LARGE FILE STORAGE)" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

# Kontrollera om Git LFS är installerat
try {
    $lfsVersion = git lfs version 2>&1
    Write-Host "✅ Git LFS är redan installerat!" -ForegroundColor Green
    Write-Host "   Version: $lfsVersion" -ForegroundColor Gray
} catch {
    Write-Host "⚠️ Git LFS är INTE installerat!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📥 INSTALLERA GIT LFS:" -ForegroundColor Cyan
    Write-Host "   1. Gå till: https://git-lfs.com" -ForegroundColor Cyan
    Write-Host "   2. Ladda ner installationsfilen för Windows" -ForegroundColor Cyan
    Write-Host "   3. Kör installationsfilen" -ForegroundColor Cyan
    Write-Host "   4. Starta om PowerShell" -ForegroundColor Cyan
    Write-Host ""
    $continue = Read-Host "🔸 Har du installerat Git LFS? (j/n)"
    if ($continue -ne "j") {
        Write-Host "❌ Avbryter. Installera Git LFS och kör skriptet igen." -ForegroundColor Red
        exit 1
    }
}

# Initiera Git LFS (behövs bara en gång per dator)
git lfs install
Write-Host "✅ Git LFS konfigurerad!" -ForegroundColor Green

# Spåra .pkl-filer med Git LFS
git lfs track "*.pkl"
Write-Host "✅ Git LFS spårar nu alla .pkl-filer!" -ForegroundColor Green

# Lägg till .gitattributes
git add .gitattributes
Write-Host "✅ .gitattributes tillagd!" -ForegroundColor Green

# =============================================
# DEL 6: TA BORT ONÖDIGA FILER
# =============================================
Write-Host "`n📚 DEL 6: RENSAR ONÖDIGA FILER" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

# Ta bort manifest.mf om den finns
if (Test-Path "Step 14 (model_backup_20260428)\manifest.mf") {
    Remove-Item "Step 14 (model_backup_20260428)\manifest.mf" -Force
    Write-Host "🗑️ manifest.mf borttagen (behövs inte)" -ForegroundColor Gray
}

# Visa vilka filer som kommer att laddas upp
Write-Host "`n📋 FILER SOM KOMMER ATT LADDAS UPP:" -ForegroundColor Cyan
Get-ChildItem -Recurse -File | Where-Object { 
    $_.Name -notlike "*.ps1" -and 
    $_.Name -notlike "*.mp4" -and 
    $_.Name -notlike "*.m4a"
} | ForEach-Object {
    $size = [math]::Round($_.Length / 1KB, 2)
    Write-Host "   📄 $($_.Name) ($size KB)" -ForegroundColor Gray
}

Read-Host "`n🔹 Tryck Enter för att fortsätta med uppladdning..."

# =============================================
# DEL 7: LÄGG TILL ALLA FILER
# =============================================
Write-Host "`n📚 DEL 7: LÄGGER TILL FILER I GIT" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

git add .
Write-Host "✅ Alla filer tillagda!" -ForegroundColor Green

# =============================================
# DEL 8: SKAPA COMMIT
# =============================================
Write-Host "`n📚 DEL 8: SKAPAR COMMIT" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

$commitMessage = "Initial commit: Insider Threat Detection ML-projekt

Projektet innehåller:
- Databricks notebooks (steg 8-13)
- dbt-modeller (transformationer)
- Tränad Random Forest-modell (.pkl)
- Presentation och dokumentation

ML-prestanda: Precision 99.1%, Recall 96.7%, F1-score 0.979
"

git commit -m $commitMessage

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Commit skapad!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Inga ändringar att committa (eller fel uppstod)" -ForegroundColor Yellow
}

# =============================================
# DEL 9: LÄGG TILL REMOTE OCH PUSH
# =============================================
Write-Host "`n📚 DEL 9: LADDAR UPP TILL GITHUB" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

# Kontrollera om remote redan finns
$remoteExists = git remote -v | Select-String "origin"

if ($remoteExists) {
    Write-Host "⚠️ Remote 'origin' finns redan." -ForegroundColor Yellow
    $changeRemote = Read-Host "🔸 Vill du uppdatera URL:en? (j/n)"
    if ($changeRemote -eq "j") {
        git remote set-url origin $repoUrl
        Write-Host "✅ Remote URL uppdaterad!" -ForegroundColor Green
    }
} else {
    git remote add origin $repoUrl
    Write-Host "✅ Remote tillagd: $repoUrl" -ForegroundColor Green
}

# Pusha till GitHub
Write-Host "`n⏳ Pushar till GitHub (detta kan ta en stund)..." -ForegroundColor Yellow
Write-Host "   Branch: $branchName" -ForegroundColor Gray

git push -u origin $branchName

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Push lyckades!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️ Push misslyckades. Vanliga orsaker:" -ForegroundColor Yellow
    Write-Host "   1. Repository finns inte på GitHub (skapa det först)" -ForegroundColor Gray
    Write-Host "   2. Du har inte rätt behörighet" -ForegroundColor Gray
    Write-Host "   3. Det finns commits på GitHub som du inte har lokalt" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔧 Försök med: git push -u origin $branchName --force" -ForegroundColor Cyan
}

# =============================================
# DEL 10: SAMMANFATTNING
# =============================================
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "✅ KLART!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host @"

┌─────────────────────────────────────────────────────────────────┐
│  SAMMANFATTNING                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📁 Repository: $repoUrl                                        │
│  🌿 Branch: $branchName                                         │
│  📦 Git LFS: Aktiverad för .pkl-filer                          │
│  📄 .gitignore: Skapad                                         │
│                                                                 │
│  UPLOADADE FILER:                                               │
│  ├── databricks/ (6 notebooks)                                 │
│  ├── docs/ (presentation + videor)                             │
│  ├── Step 6 (dbt)/ (dbt-modeller)                              │
│  ├── Step 14 (model_backup)/ (.pkl-filer)                      │
│  └── Medical_Internal_Attacks_Dataset.csv                      │
│                                                                 │
│  NÄSTA STEG:                                                    │
│  ├── Gå till: github.com/$githubUsername/$repoName             │
│  ├── Kontrollera att alla filer kommit med                     │
│  └── Dela länken i din portfolio!                              │
└─────────────────────────────────────────────────────────────────┘
"@