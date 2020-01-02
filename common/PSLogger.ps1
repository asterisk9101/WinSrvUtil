function New-Logger {
    <#
    .SYNOPSIS
    Invoke-Logger のための初期化を行う

    .DESCRIPTION
    New-Logger は Invoke-Logger が必要とする環境変数（グローバル変数）を設定する。
    設定するグローバル変数は以下の２つ。
    $Global:LoggerPath
    $Global:LoggerToScreen

    既に存在するファイルが指定されたとき、デフォルトではそのファイルをローテーションする。
    ローテーション名は BaseName_yyyyMMdd_HHmmss.ext となる。
    ローテーションしたとき保持するファイル数の上限は Rotate パラメータで指定できる。

    .PARAMETER Path
    ログ出力先となるファイルを指定する。

    .PARAMETER Rotate
    ログローテーションするときに保持する世代数を指定する。

    .PARAMETER Append
    ログ出力先に既にファイルが存在するとき追記する（ローテーションしない）。

    .PARAMETER ToScreen
    ログに出力するメッセージを画面にも出力する。

    .INPUTS
    なし。

    .OUTPUTS
    ログファイルのローテーション（リネーム・削除）。
    ログ出力フォルダの作成。

    #>
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$Path,
        [Parameter(Mandatory=$True,Position=2)]
        [int]$Rotate,
        [Parameter(Mandatory=$False,Position=3)]
        [switch]$Append,
        [Parameter(Mandatory=$False,Position=4)]
        [switch]$ToScreen
    )
    $ErrorActionPreference = "stop"

    if (-not (Test-Path -IsValid $Path)) {
        throw "有効なパスではありません: $Path"
    }
    if (Test-Path -PathType Container $Path) {
        throw "フォルダが指定されました: $Path"
    }
    
    if (Test-Path -PathType Leaf $Path) {
        if (-not $Append) {
            # 既存のファイルをローテーションする
            $item = Get-Item $Path
            $srcPath = $item.FullName
            $destName = $item.BaseName + "_" + $item.LastWriteTime.ToString("yyyyMMdd_HHmmss") + $item.Extension
            $destPath = Join-Path $item.Directory $destname
            Move-Item -Path $srcPath -Destination $destPath -Force # 移動先にファイルがあれば上書きする

            # 古いファイルを削除する
            $rotateName = $item.BaseName + "_*_*" + $item.Extension
            $rotatePath = Join-Path $item.Directory $rotateName
            Get-Item $rotatePath | Sort-Object -Descending LastWriteTime | Select-Object -Skip $Rotate | Remove-Item -Force
        }
    } else {
        $Folder = Split-Path -Parent -Path $Path
        mkdir -force $Folder | Out-Null
    }

    $Global:LoggerPath = $Path
    $Global:LoggerToScreen = $ToScreen

    return
}
function Invoke-Logger {
    <#
    .SYNOPSIS
    ファイルにログメッセージを追記する

    .DESCRIPTION
    Invoke-Logger は以下のフォーマットでログメッセージを組み立てて、それをファイルへ書き込む。

    DateTime,ComputerName,pid,ScriptName,Level,Message

    書き込み先のファイルを特定するためにグローバル変数を必要とするため、New-Logger による初期化が必要となる。
    Invoke-Logger はログファイルへの書き込みに失敗したとき、デフォルトでは 1 秒待機して 3 回リトライする。

    .PARAMETER Message
    ログへ出力するメッセージを指定する。

    .PARAMETER Level
    ログへ出力するメッセージレベルを指定する。

    .PARAMETER Interval
    ログ出力に失敗したときにリトライを待機する時間を指定する。

    .PARAMETER Retry
    ログ出力に失敗したときにリトライする回数を指定する。

    .PARAMETER Encoding
    ログ出力のエンコーディングを指定する。

    .INPUTS
    なし。

    .OUTPUTS
    ログファイルの作成・追記。

    #>
    [Alias("logger")]
    param(
        [Parameter(Mandatory=$False,Position=1)]
        [string]$Message = "",
        [Parameter(Mandatory=$False,Position=2)]
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",
        [Parameter(Mandatory=$False,Position=3)]
        [int]$Interval = 1,
        [Parameter(Mandatory=$False,Position=4)]
        [int]$Retry = 3,
        [Parameter(Mandatory=$False,Position=5)]
        [ValidateSet("ascii","bigendianunicode","default","unicode","utf8","utf32")]
        [string]$Encoding = "default"
    )
    $ErrorActionPreference = "continue"

    $Path = $Global:LoggerPath
    $ToScreen = $Global:LoggerToScreen

    if (-not $Path) {
        throw "LoggerPath が設定されていません。New-Logger を実行してください。"
    }

    # スクリプト名(もし空ならコンソールから実行されたものとする)
    $ScriptName = $MyInvocation.ScriptName
    if ($ScriptName) {
        $ScriptName = Split-Path -Leaf -Path $ScriptName
    } else {
        $ScriptName = "Console"
    }
    
    # 出力メッセージを組み立てる
    $date = [DateTime]::Now.ToString("yyyy/MM/dd HH:mm:ss")
    $msg = @($date, $Env:COMPUTERNAME, $pid, $ScriptName, $Level, $Message) -join ","

    # ファイルへ書き込む(失敗した場合は待機してリトライ)
    for($i = 0; $i -lt $Retry; $i++) {
        Write-Output $msg | Out-File -Append $Path -Encoding $Encoding
        if ($?) { break }
        Start-Sleep -Seconds $Interval
    }

    # ToScreen の場合は出力を返す
    if ($ToScreen) {
        return $msg
    } else {
        return 
    }
}
