###############################################################################
# �C�x���g���O�o��
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
# ������
########################
$ErrorActionPreference = "continue"

# ���s�t�@�C�����g�̏��
$item = Get-Item $MyInvocation.MyCommand.Path
$here = $item.Directory
$basename = $item.BaseName

# ���ʊ֐��̓ǂݍ���
. $here\common\PSLogger.ps1

# ���s���O�̏�����
$logpath = Join-Path $LogDir ($basename + ".log")
New-Logger -Path $logpath -Rotate $Rotate -ToScreen

# �C�x���g���O�o�͐�̊m�F
$ResolvedOutFolder = Resolve-Path $OutFolder | Select-Object -ExpandProperty Path
if (-not $?) {
    logger -level ERROR "�o�͐�t�H���_������܂���: $OutFolder"
    exit 1
}

logger "�C�x���g���O�o�͊J�n=================================================="

########################
# �C�x���g���O�o�͊���
########################
$StartDate = $Date.AddDays(-1).ToString("yyyy-MM-dd")
$EndDate = $Date.ToString("yyyy-MM-dd")

logger "�o�͑Ώۂ� ${EndDate} �ł��B" # 15���Ԃ����̂� EndDate �̓��t������

$Log | ForEach-Object {

    $FileNameTempl = $Env:COMPUTERNAME + "_" + $_ + "_" # ComputerName_Log_
    $LogPath = Join-Path $ResolvedOutFolder $FileNameTempl
    
    ########################
    # Evtx �G�N�X�|�[�g
    ########################
    $OutEvtx = $LogPath + $EndDate + ".evtx"
    if (Test-Path $OutEvtx) {
        logger -level WARN "���ɑ��݂��܂�: $OutEvtx"
    } else {
        logger "Evtx���O($_)���o�͂��܂�: ${OutEvtx}"
        wevtutil.exe epl $_ $OutEvtx /q:"*[System[TimeCreated[@SystemTime>='${StartDate}T15:00:00.000Z' and @SystemTime<='${EndDate}T15:00:00.000Z']]]"
    }

    #########################
    # Evtx -> Txt �ϊ�
    #########################
    $OutTxt = $LogPath + $EndDate + ".txt"
    if (Test-Path $OutTxt) {
        logger -level WARN "���ɑ��݂��܂�: $OutTxt"
    } else {
        logger "Evtx���O($_)���e�L�X�g�ɕϊ����܂�: ${OutTxt}"
        wevtutil.exe qe $OutEvtx /lf /f:text /rd:false | Out-File $OutTxt
    }

    #########################
    # Evtx, Txt ���܂Ƃ߂Ĉ��k
    #########################
    $OutZip = $LogPath + $EndDate + ".zip"
    logger "���k���܂�: $OutZip"
    Compress-Archive -Path $OutEvtx, $OutTxt -DestinationPath $OutZip -Force # ���ɑ��݂���ꍇ�͏㏑��

    #########################
    # Evtx, Txt ���폜
    #########################
    if ($?) {
        # ���k�����������ꍇ
        Get-Item -Path $LogPath*.txt, $LogPath*.evtx | ForEach-Object {
            $path = $_.FullName
            logger "�폜���܂�: $path"
            Remove-Item -Force $path
        }
    }

    #########################
    # �Â� zip ���폜
    #########################
    Get-Item $LogPath*.zip | Sort-Object -Descending LastWriteTime | Select-Object -Skip $Rotate | ForEach-Object {
        $path = $_.FullName
        logger "�폜���܂�: $path"
        Remove-Item -Force $path
    }
}

logger "�C�x���g���O�o�͏I��=================================================="
exit 0
