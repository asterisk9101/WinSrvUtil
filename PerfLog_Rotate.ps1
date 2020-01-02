###############################################################################
# パフォーマンスログローテーション
###############################################################################
Param(
    # 実行ログの出力先（デフォルトカレントディレクトリ）
    [string]$LogDir = ".",

    # データコレクタセット名（デフォルトコンピュータ名）
    [string]$DataCollectorSetName = $Env:COMPUTERNAME,

    # 保持するログの世代数（デフォルト65日分）
    [int]$Rotate = 65
)
$ErrorActionPreference = "continue"

# 実行ファイル自身の情報
$item = Get-Item $MyInvocation.MyCommand.Path
$here = $item.Directory
$basename = $item.BaseName

# 共通関数の読み込み
. $here\common\PSLogger.ps1

# 実行ログの初期化
$logpath = Join-Path $logdir ($basename + ".log")
New-Logger -Path $logpath -Rotate $Rotate -ToScreen


logger "パフォーマンスログローテーション開始=================================================="

$DCS = New-Object -ComObject PLA.DataCollectorSet
$DCS.query($DataCollectorSetName, "localhost")
$RootPath = $DCS.RootPath -replace '%systemdrive%', $Env:SystemDrive

if (-not (Test-Path $RootPath)) {
    logger -level ERROR "データコレクタセットのルートパスが見つかりません: ${DataCollectorSetName}"

    # COM オブジェクトの開放
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($DCS) | Out-Null

    exit 1
}

##########################
# パフォーマンスログ停止
##########################
logger "データコレクタセットを停止します: ${DataCollectorSetName}"
$DCS.stop($True)
if ($DCS.status -ne 0) {
    logger -level ERROR "データコレクタセットが停止していません: ${DataCollectorSetName}"
}

##########################
# 変換
##########################
# 変換されていない blg ファイルを検索する
#$blgfiles = Get-ChildItem -File -Recurse $RootPath | Group-Object BaseName | Where-Object Count -eq 1 | ForEach-Object Group | Where-Object Extension -eq ".blg"
#$blgfiles | ForEach-Object {
#    $outpath = Join-Path $_.Directory ($_.BaseName + ".csv")
#    relog $_.FullName -f CSV -o $outpath
#}
##########################
# 圧縮
##########################
Get-ChildItem -File -Recurse $RootPath | Where-Object { $_.Extension -eq ".blg" } | ForEach-Object {
    $path = $_.FullName
    $dest = $_.BaseName + ".zip"
    $dest = Join-Path $_.Directory $dest
    logger "圧縮します: $path"
    Compress-Archive -Path $path -DestinationPath $dest -Force
    # $here\7z.exe a $dest $path
    logger "削除します: $path"
    Remove-Item -Force $path
}

##########################
# ローテーション
##########################
Get-ChildItem -File -Recurse $RootPath | Sort-Object -Descending LastWriteTime | Select-Object -Skip $Rotate | ForEach-Object {
    $path = $_.FullName
    logger "削除します: $path"
    Remove-Item -Force $path
}

##########################
# パフォーマンスログ開始
##########################
logger "データコレクタセットを開始します: ${DataCollectorSetName}"
$DCS.start($True)
if ($DCS.status -ne 1) {
    logger -level ERROR "データコレクタセットが開始していません: ${DataCollectorSetName}"

    # COM オブジェクトの開放
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($DCS) | Out-Null

    exit 1
}

# COM オブジェクトの開放
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($DCS) | Out-Null

logger "パフォーマンスログローテーション終了=================================================="
exit 0
