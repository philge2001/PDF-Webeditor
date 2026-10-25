# Baut die Webapp nach dist\ – Gegenstück zu scripts/build.sh für Windows (PowerShell 5.1).
#
# Aufruf (PowerShell, im Projektordner):
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1           # Release-Build
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Dev      # schneller gebaut, größer
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Serve    # bauen und lokal starten
#
# Einmalig vorher:
#   rustup target add wasm32-unknown-unknown
#   cargo install wasm-bindgen-cli --version 0.2.129 --locked
param(
    [switch]$Dev,
    [switch]$Serve,
    [int]$Port = 8080
)
$ErrorActionPreference = "Stop"

# Externes Programm starten; Fehler nur über den Exit-Code. (Windows PowerShell 5.1 würde sonst
# jede Ausgabe auf stderr, z. B. Fortschrittsmeldungen von cargo, als Fehler werten und abbrechen.)
function Invoke-Tool([string]$Exe, [string[]]$ArgList) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $Exe @ArgList 2>&1 | ForEach-Object { Write-Host $_ }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "$Exe $($ArgList -join ' ') fehlgeschlagen (Exit-Code $code)" }
}

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

# --- wasm-bindgen-cli muss exakt zur Version in Cargo.toml passen ---
$Want = (Select-String -Path "Cargo.toml" -Pattern 'wasm-bindgen = "=([0-9.]+)"').Matches[0].Groups[1].Value
$Have = ""
if (Get-Command "wasm-bindgen" -ErrorAction SilentlyContinue) {
    $Have = ((& wasm-bindgen --version) -split " ")[1]
}
if ($Have -ne $Want) {
    Write-Host "wasm-bindgen-cli $Want benötigt (gefunden: $(if ($Have) { $Have } else { 'keine' }))."
    Write-Host "Installieren: cargo install wasm-bindgen-cli --version $Want --locked"
    exit 1
}

# --- PDFium als WebAssembly (pdfium-lib), wie scripts/fetch-pdfium.sh ---
$PdfiumVersion = "7902"
$Vendor = Join-Path $Root "vendor\pdfium"
$VersionFile = Join-Path $Vendor "VERSION"
if ((Test-Path (Join-Path $Vendor "pdfium.wasm")) -and (Test-Path $VersionFile) -and
    ((Get-Content $VersionFile -Raw).Trim() -eq $PdfiumVersion)) {
    Write-Host "PDFium $PdfiumVersion liegt schon in $Vendor"
} else {
    $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pdfwebeditor-pdfium-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force $Tmp | Out-Null
    try {
        # curl.exe und tar.exe sind seit Windows 10 (1803) eingebaut.
        $Url = "https://github.com/paulocoutinhox/pdfium-lib/releases/download/$PdfiumVersion/wasm.tgz"
        Write-Host "Lade $Url"
        Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Tmp "wasm.tgz"), $Url)
        Invoke-Tool "tar.exe" @("-xzf", (Join-Path $Tmp "wasm.tgz"), "-C", $Tmp)

        if (Test-Path $Vendor) { Remove-Item -Recurse -Force $Vendor }
        $Lic = Join-Path $Vendor "licenses"
        New-Item -ItemType Directory -Force $Lic | Out-Null
        Copy-Item (Join-Path $Tmp "release\node\pdfium.js") $Vendor
        Copy-Item (Join-Path $Tmp "release\node\pdfium.wasm") $Vendor

        # Lizenztexte: pdfium-lib (MIT) und PDFium samt Drittbibliotheken (aus dem bblanchon-Paket).
        Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Lic "pdfium-lib.md"),
            "https://raw.githubusercontent.com/paulocoutinhox/pdfium-lib/master/LICENSE.md")
        Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Tmp "bb.tgz"),
            "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F7881/pdfium-wasm.tgz")
        Invoke-Tool "tar.exe" @("-xzf", (Join-Path $Tmp "bb.tgz"), "-C", $Tmp, "licenses")
        Copy-Item (Join-Path $Tmp "licenses\*") $Lic

        Set-Content -Path $VersionFile -Value $PdfiumVersion -Encoding ASCII
        Write-Host "PDFium $PdfiumVersion nach $Vendor geladen"
    } finally {
        Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
    }
}

# --- Liberation-Schriften (werden im Browser nachgeladen), wie scripts/fetch-fonts.sh ---
$Rev = (Select-String -Path "Cargo.toml" -Pattern 'PDF-Tool", rev = "([0-9a-f]+)"').Matches[0].Groups[1].Value
$Fonts = Join-Path $Root "vendor\fonts"
$FontRevFile = Join-Path $Fonts "REV"
if ((Test-Path $FontRevFile) -and ((Get-Content $FontRevFile -Raw).Trim() -eq $Rev)) {
    Write-Host "Schriften (PDF-Tool $Rev) liegen schon in $Fonts"
} else {
    if (Test-Path $Fonts) { Remove-Item -Recurse -Force $Fonts }
    New-Item -ItemType Directory -Force $Fonts | Out-Null
    $Base = "https://raw.githubusercontent.com/philge2001/PDF-Tool/$Rev/assets/fonts"
    foreach ($n in @("Sans", "Serif", "Mono")) {
        foreach ($st in @("Regular", "Bold", "Italic", "BoldItalic")) {
            $f = "Liberation$n-$st.ttf"
            Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Fonts $f), "$Base/liberation/$f")
        }
    }
    Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Fonts "COPYRIGHT-Liberation.txt"), "$Base/liberation/COPYRIGHT")
    Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Fonts "OFL.txt"), "$Base/OFL.txt")
    Set-Content -Path $FontRevFile -Value $Rev -Encoding ASCII
    Write-Host "Liberation-Schriften (PDF-Tool $Rev) nach $Fonts geladen"
}

# --- Rust → WebAssembly ---
$BuildProfile = if ($Dev) { "debug" } else { "release" }
$CargoArgs = @("build", "--target", "wasm32-unknown-unknown")
if (-not $Dev) { $CargoArgs += "--release" }
Invoke-Tool "cargo" $CargoArgs

# --- dist\ zusammenstellen ---
$Dist = Join-Path $Root "dist"
if (Test-Path $Dist) { Remove-Item -Recurse -Force $Dist }
New-Item -ItemType Directory -Force (Join-Path $Dist "pkg") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $Dist "pdfium") | Out-Null
$Wasm = Join-Path $Root "target\wasm32-unknown-unknown\$BuildProfile\pdf_webeditor.wasm"
Invoke-Tool "wasm-bindgen" @("--target", "web", "--no-typescript", "--out-dir", (Join-Path $Dist "pkg"), $Wasm)
# Optional (Release): wasm-opt aus binaryen verkleinert das WebAssembly um rund ein Drittel.
if (-not $Dev -and (Get-Command "wasm-opt" -ErrorAction SilentlyContinue)) {
    $Opt = Join-Path $Dist "pkg\pdf_webeditor_bg.wasm"
    Write-Host "wasm-opt -Oz …"
    Invoke-Tool "wasm-opt" @("-Oz", "--enable-bulk-memory", "--enable-nontrapping-float-to-int", "--enable-sign-ext",
        "--enable-mutable-globals", "--enable-reference-types", "--enable-multivalue", $Opt, "-o", $Opt)
}
Copy-Item (Join-Path $Root "web\index.html") $Dist
Copy-Item (Join-Path $Vendor "pdfium.js") (Join-Path $Dist "pdfium")
Copy-Item (Join-Path $Vendor "pdfium.wasm") (Join-Path $Dist "pdfium")
Copy-Item -Recurse (Join-Path $Vendor "licenses") (Join-Path $Dist "pdfium")
New-Item -ItemType Directory -Force (Join-Path $Dist "fonts") | Out-Null
Copy-Item (Join-Path $Fonts "*.ttf") (Join-Path $Dist "fonts")
Copy-Item (Join-Path $Fonts "*.txt") (Join-Path $Dist "fonts")

$SizeMb = [math]::Round(((Get-ChildItem -Recurse $Dist | Measure-Object -Property Length -Sum).Sum / 1MB), 1)
Write-Host "Fertig: dist\ ($SizeMb MB)"

# --- optional: lokal starten (Python: „python“ oder der Launcher „py“) ---
if ($Serve) {
    $Python = @("python", "py", "python3") | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } |
        Select-Object -First 1
    if (-not $Python) {
        Write-Host "Kein Python gefunden. dist\ mit einem beliebigen Webserver ausliefern, z. B.:"
        Write-Host "  npx --yes http-server dist -p $Port"
        exit 1
    }
    Write-Host "Webeditor läuft auf http://localhost:$Port  (Beenden mit Strg+C)"
    & $Python -m http.server $Port --directory $Dist
}
