function New-Logger {
    <#
    .SYNOPSIS
    Invoke-Logger �̂��߂̏��������s��

    .DESCRIPTION
    New-Logger �� Invoke-Logger ���K�v�Ƃ�����ϐ��i�O���[�o���ϐ��j��ݒ肷��B
    �ݒ肷��O���[�o���ϐ��͈ȉ��̂Q�B
    $Global:LoggerPath
    $Global:LoggerToScreen

    ���ɑ��݂���t�@�C�����w�肳�ꂽ�Ƃ��A�f�t�H���g�ł͂��̃t�@�C�������[�e�[�V��������B
    ���[�e�[�V�������� BaseName_yyyyMMdd_HHmmss.ext �ƂȂ�B
    ���[�e�[�V���������Ƃ��ێ�����t�@�C�����̏���� Rotate �p�����[�^�Ŏw��ł���B

    .PARAMETER Path
    ���O�o�͐�ƂȂ�t�@�C�����w�肷��B

    .PARAMETER Rotate
    ���O���[�e�[�V��������Ƃ��ɕێ����鐢�㐔���w�肷��B

    .PARAMETER Append
    ���O�o�͐�Ɋ��Ƀt�@�C�������݂���Ƃ��ǋL����i���[�e�[�V�������Ȃ��j�B

    .PARAMETER ToScreen
    ���O�ɏo�͂��郁�b�Z�[�W����ʂɂ��o�͂���B

    .INPUTS
    �Ȃ��B

    .OUTPUTS
    ���O�t�@�C���̃��[�e�[�V�����i���l�[���E�폜�j�B
    ���O�o�̓t�H���_�̍쐬�B

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
        throw "�L���ȃp�X�ł͂���܂���: $Path"
    }
    if (Test-Path -PathType Container $Path) {
        throw "�t�H���_���w�肳��܂���: $Path"
    }
    
    if (Test-Path -PathType Leaf $Path) {
        if (-not $Append) {
            # �����̃t�@�C�������[�e�[�V��������
            $item = Get-Item $Path
            $srcPath = $item.FullName
            $destName = $item.BaseName + "_" + $item.LastWriteTime.ToString("yyyyMMdd_HHmmss") + $item.Extension
            $destPath = Join-Path $item.Directory $destname
            Move-Item -Path $srcPath -Destination $destPath -Force # �ړ���Ƀt�@�C��������Ώ㏑������

            # �Â��t�@�C�����폜����
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
    �t�@�C���Ƀ��O���b�Z�[�W��ǋL����

    .DESCRIPTION
    Invoke-Logger �͈ȉ��̃t�H�[�}�b�g�Ń��O���b�Z�[�W��g�ݗ��ĂāA������t�@�C���֏������ށB

    DateTime,ComputerName,pid,ScriptName,Level,Message

    �������ݐ�̃t�@�C������肷�邽�߂ɃO���[�o���ϐ���K�v�Ƃ��邽�߁ANew-Logger �ɂ�鏉�������K�v�ƂȂ�B
    Invoke-Logger �̓��O�t�@�C���ւ̏������݂Ɏ��s�����Ƃ��A�f�t�H���g�ł� 1 �b�ҋ@���� 3 �񃊃g���C����B

    .PARAMETER Message
    ���O�֏o�͂��郁�b�Z�[�W���w�肷��B

    .PARAMETER Level
    ���O�֏o�͂��郁�b�Z�[�W���x�����w�肷��B

    .PARAMETER Interval
    ���O�o�͂Ɏ��s�����Ƃ��Ƀ��g���C��ҋ@���鎞�Ԃ��w�肷��B

    .PARAMETER Retry
    ���O�o�͂Ɏ��s�����Ƃ��Ƀ��g���C����񐔂��w�肷��B

    .PARAMETER Encoding
    ���O�o�͂̃G���R�[�f�B���O���w�肷��B

    .INPUTS
    �Ȃ��B

    .OUTPUTS
    ���O�t�@�C���̍쐬�E�ǋL�B

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
        throw "LoggerPath ���ݒ肳��Ă��܂���BNew-Logger �����s���Ă��������B"
    }

    # �X�N���v�g��(������Ȃ�R���\�[��������s���ꂽ���̂Ƃ���)
    $ScriptName = $MyInvocation.ScriptName
    if ($ScriptName) {
        $ScriptName = Split-Path -Leaf -Path $ScriptName
    } else {
        $ScriptName = "Console"
    }
    
    # �o�̓��b�Z�[�W��g�ݗ��Ă�
    $date = [DateTime]::Now.ToString("yyyy/MM/dd HH:mm:ss")
    $msg = @($date, $Env:COMPUTERNAME, $pid, $ScriptName, $Level, $Message) -join ","

    # �t�@�C���֏�������(���s�����ꍇ�͑ҋ@���ă��g���C)
    for($i = 0; $i -lt $Retry; $i++) {
        Write-Output $msg | Out-File -Append $Path -Encoding $Encoding
        if ($?) { break }
        Start-Sleep -Seconds $Interval
    }

    # ToScreen �̏ꍇ�͏o�͂�Ԃ�
    if ($ToScreen) {
        return $msg
    } else {
        return 
    }
}
