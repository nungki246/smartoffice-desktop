# Convert all TFrame module views to TForm for Lazarus designer editing

$modules = @(
    "accounting",
    "apps", 
    "billing",
    "dashboard",
    "doctor",
    "employees",
    "perawat",
    "rbac",
    "settings"
)

function Convert-ViewToForm($moduleName) {
    $base = "C:\0. Riset\SIMRS_Lazarus\src\modules\$moduleName"
    $viewPas = "$base\u${moduleName}View.pas"
    $viewLfm = "$base\u${moduleName}View.lfm"
    $modulePas = "$base\u${moduleName}Module.pas"
    $lpi = "$base\SIMRS-$moduleName.lpi"
    $lpr = "$base\SIMRS-$moduleName.lpr"

    if (-not (Test-Path $viewPas)) { 
        Write-Host ("SKIP {0}: {1} not found" -f $moduleName, $viewPas) -ForegroundColor Yellow
        return 
    }

    Write-Host ("Converting {0}..." -f $moduleName) -ForegroundColor Green

    # 1. Convert .pas: TModuleView -> TForm, add BorderStyle := bsNone
    $pasContent = Get-Content $viewPas -Raw
    $className = "T${moduleName^}Form"
    $pasContent = $pasContent -replace 'T\w+View\s*=\s*class\s*\(TModuleView\)', "$className = class(TForm)"
    $pasContent = $pasContent -replace 'T\w+View\s*=\s*class\s*\(TFrame\)', "$className = class(TForm)"
    
    # Fix constructor: add BorderStyle := bsNone
    $pasContent = $pasContent -replace 
        '(constructor T\w+View\.Create\(AOwner: TComponent\);[\s\S]*?begin\s*\n\s*inherited Create\(AOwner\);)', 
        '$1`n  BorderStyle := bsNone;'

    # Fix implementation uses: remove DB, sqldb if present (duplicates from Forms)
    $pasContent = $pasContent -replace 
        'implementation\s*\n\s*uses\s*\n\s*(.*?)\n\s*DB,\s*sqldb,', 
        'implementation`nuses`n  $1`n'

    # Fix function/procedure separators: end\n  function -> end;\n  function
    $pasContent = $pasContent -replace '(?m)^end\s*\n\s*(function|procedure)\s+T\w+Form\.', 'end;`n  $1 T' + $moduleName + 'Form.'
    $pasContent = $pasContent -replace '(?m)^end\s*\n\s*(procedure)\s+T\w+Form\.', 'end;`n  $1 T' + $moduleName + 'Form.'
    $pasContent = $pasContent -replace '(?m)^end\s*\n\s*(function|procedure)\s+\w+', 'end;`n  $1'

    Set-Content $viewPas $pasContent -Encoding UTF8

    # 2. Convert .lfm: Frame -> Form, remove TabOrder/DesignLeft/DesignTop
    if (Test-Path $viewLfm) {
        $lfmContent = Get-Content $viewLfm -Raw
        $lfmContent = $lfmContent -replace 'object \w+View: T\w+View', "object ${moduleName^}Form: T${moduleName^}Form"
        $lfmContent = $lfmContent -replace '^\s*TabOrder = \d+\r?\n', ''
        $lfmContent = $lfmContent -replace '^\s*DesignLeft = \d+\r?\n', ''
        $lfmContent = $lfmContent -replace '^\s*DesignTop = \d+\r?\n', ''
        $lfmContent = $lfmContent -replace '^\s*BorderStyle = bsNone\r?\n', ''
        $lfmContent = $lfmContent -replace 'ResourceBaseClass Value="Frame"', 'ResourceBaseClass Value="Form"'
        Set-Content $viewLfm $lfmContent -Encoding UTF8
    }

    # 3. Update Module class: CreateView returns Form
    if (Test-Path $modulePas) {
        $modContent = Get-Content $modulePas -Raw
        $modContent = $modContent -replace 
            'uses\s+u\w+View;', 
            "uses u${moduleName}View;"
        $modContent = $modContent -replace 
            'Result := T\w+View\.Create\(nil\);', 
            "Result := T${moduleName^}Form.Create(nil);"
        Set-Content $modulePas $modContent -Encoding UTF8
    }

    # 4. Update .lpi: ResourceBaseClass Frame -> Form
    if (Test-Path $lpi) {
        $lpiContent = Get-Content $lpi -Raw
        $lpiContent = $lpiContent -replace 'ResourceBaseClass Value="Frame"', 'ResourceBaseClass Value="Form"'
        $lpiContent = $lpiContent -replace 'ComponentName Value="\w+View"', 'ComponentName Value="T' + $moduleName + 'Form"'
        Set-Content $lpi $lpiContent -Encoding UTF8
    }

    # 5. Update .lpr: use Form class
    if (Test-Path $lpr) {
        $lprContent = Get-Content $lpr -Raw
        $lprContent = $lprContent -replace 
            'u\w+View,', 
            "u${moduleName}View,"
        $lprContent = $lprContent -replace 
            'T\w+View\.Create\(nil\)', 
            "T${moduleName^}Form.Create(nil)"
        Set-Content $lpr $lprContent -Encoding UTF8
    }

    Write-Host ("Done {0}" -f $moduleName) -ForegroundColor Cyan
}

foreach ($m in $modules) {
    Convert-ViewToForm $m
}

Write-Host "All conversions complete!" -ForegroundColor Green