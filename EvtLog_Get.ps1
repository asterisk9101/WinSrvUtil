###############################################################################
# イベントログ出力
###############################################################################
param(
    [string]$LogDir = ".",
    [string]$OutFolder = ".",
    [DateTime]$Date = [DateTime]::Today.AddDays(-1),
    [int]$Rotate = 65,
    [ValidateSet("Application", "System", "Security")]
    [string[]]$Log = @("Application", "System", "Security")
)
########################
# 初期化
########################
$ErrorActionPreference = "continue"

# 実行ファイル自身の情報
$item = Get-Item $MyInvocation.MyCommand.Path
$here = $item.Directory
$basename = $item.BaseName

# 共通関数の読み込み
. $here\common\PSLogger.ps1

# 実行ログの初期化
$logpath = Join-Path $LogDir ($basename + ".log")
New-Logger -Path $logpath -Rotate $Rotate -ToScreen

# イベントログ出力先の確認
$ResolvedOutFolder = Resolve-Path $OutFolder | Select-Object -ExpandProperty Path
if (-not $?) {
    logger -level ERROR "出力先フォルダがありません: $OutFolder"
    exit 1
}

logger "イベントログ出力開始=================================================="

########################
# イベントログ出力期間
########################
$StartDate = $Date.AddDays(-1).ToString("yyyy-MM-dd")
$EndDate = $Date.ToString("yyyy-MM-dd")

logger "出力対象は ${EndDate} です。" # 15時間ずれるので EndDate の日付が取れる

$Log | ForEach-Object {

    $FileNameTempl = $Env:COMPUTERNAME + "_" + $_ + "_" # ComputerName_Log_
    $LogPath = Join-Path $ResolvedOutFolder $FileNameTempl
    
    ########################
    # Evtx エクスポート
    ########################
    $OutEvtx = $LogPath + $EndDate + ".evtx"
    if (Test-Path $OutEvtx) {
        logger -level WARN "既に存在します: $OutEvtx"
    } else {
        logger "Evtxログ($_)を出力します: ${OutEvtx}"
        wevtutil.exe epl $_ $OutEvtx /q:"*[System[TimeCreated[@SystemTime>='${StartDate}T15:00:00.000Z' and @SystemTime<='${EndDate}T15:00:00.000Z']]]"
    }

    #########################
    # Evtx -> Txt 変換
    #########################
    $OutTxt = $LogPath + $EndDate + ".txt"
    if (Test-Path $OutTxt) {
        logger -level WARN "既に存在します: $OutTxt"
    } else {
        logger "Evtxログ($_)をテキストに変換します: ${OutTxt}"
        wevtutil.exe qe $OutEvtx /lf /f:text /rd:false | Out-File $OutTxt
    }

    #########################
    # Evtx, Txt をまとめて圧縮
    #########################
    $OutZip = $LogPath + $EndDate + ".zip"
    logger "圧縮します: $OutZip"
    Compress-Archive -Path $OutEvtx, $OutTxt -DestinationPath $OutZip -Force # 既に存在する場合は上書き

    #########################
    # Evtx, Txt を削除
    #########################
    if ($?) {
        # 圧縮が成功した場合
        Get-Item -Path $LogPath*.txt, $LogPath*.evtx | ForEach-Object {
            $path = $_.FullName
            logger "削除します: $path"
            Remove-Item -Force $path
        }
    }

    #########################
    # 古い zip を削除
    #########################
    Get-Item $LogPath*.zip | Sort-Object -Descending LastWriteTime | Select-Object -Skip $Rotate | ForEach-Object {
        $path = $_.FullName
        logger "削除します: $path"
        Remove-Item -Force $path
    }
}

logger "イベントログ出力終了=================================================="
exit 0
