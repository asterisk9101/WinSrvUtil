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
$StartDate = $Date.ToString("yyyy-MM-dd")
$EndDate = $Date.AddDays(1).ToString("yyyy-MM-dd")

logger "�o�͑Ώۂ� ${StartDate} �ł��B"

$Log | ForEach-Object {

    $FileNameTempl = $Env:COMPUTERNAME + "_" + $_ + "_" # ComputerName_Log_
    $LogPath = Join-Path $ResolvedOutFolder $FileNameTempl
    
    ########################
    # Evtx �G�N�X�|�[�g
    ########################
    $OutEvtx = $LogPath + $StartDate + ".evtx"
    if (Test-Path $OutEvtx) {
        logger -level WARN "���ɑ��݂��܂�: $OutEvtx"
    } else {
        logger "Evtx���O($_)���o�͂��܂�: ${OutEvtx}"
        wevtutil.exe epl $_ $OutEvtx /q:"*[System[TimeCreated[@SystemTime>='${StartDate}T15:00:00.000Z' and @SystemTime<='${EndDate}T15:00:00.000Z']]]"
    }

    #########################
    # Evtx -> Csv �ϊ�
    #########################
    $OutCSV = $LogPath + $StartDate + ".txt"
    if (Test-Path $OutCSV) {
        logger -level WARN "���ɑ��݂��܂�: $OutCSV"
    } else {
        logger "Evtx���O($_)���e�L�X�g�ɕϊ����܂�: ${OutCSV}"
        wevtutil.exe qe $OutEvtx /lf /f:text /rd:false | Out-File $OutCSV
    }

    #########################
    # Evtx, Csv ���܂Ƃ߂Ĉ��k
    #########################
    $OutZip = $LogPath + $StartDate + ".zip"
    logger "���k���܂�: $OutZip"
    Compress-Archive -Path $OutEvtx, $OutCsv -DestinationPath $OutZip -Force # ���ɑ��݂���ꍇ�͏㏑��

    #########################
    # Evtx, Csv ���폜
    #########################
    if ($?) {
        # ���k�����������ꍇ
        Get-Item -Path $LogPath*.txt, $LogPath*.evtx | ForEach-Object {
            logger "�폜���܂�: $_"
            Remove-Item -Force $_.FullName
        }
    }

    #########################
    # �Â� zip ���폜
    #########################
    Get-Item $LogPath*.zip | Sort-Object -Descending LastWriteTime | Select-Object -Skip $Rotate | ForEach-Object {
        logger "�폜���܂�: $_"
        Remove-Item -Force $_.FullName
    }
}

logger "�C�x���g���O�o�͏I��=================================================="
exit 0