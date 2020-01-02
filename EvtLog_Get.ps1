###############################################################################
# �C�x���g���O�o��
###############################################################################
param(
    # ���s���O�̏o�͐�i�f�t�H���g�J�����g�f�B���N�g���j
    [string]$LogDir = ".",

    # �C�x���g���O(zip)�̏o�͐�i�f�t�H���g�J�����g�f�B���N�g���j
    [string]$OutDir = ".",

    # �G�N�X�|�[�g�Ώۂ̓��t�i�f�t�H���g1���O�j
    [DateTime]$Date = [DateTime]::Today.AddDays(-1),

    # �ێ�����t�@�C�����㐔�i�f�t�H���g65�����j
    [int]$Rotate = 65,

    # �G�N�X�|�[�g���郍�O�̎�ށi�f�t�H���g3��ޑS�āj
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
$ResolvedOutDir = Resolve-Path $OutDir | Select-Object -ExpandProperty Path
if (-not $?) {
    logger -level ERROR "�o�͐�t�H���_������܂���: $OutDir"
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
    $LogPath = Join-Path $ResolvedOutDir $FileNameTempl
    
    ########################
    # Evtx �G�N�X�|�[�g
    ########################
    $OutEvtx = $LogPath + $EndDate + ".evtx"
    logger "Evtx���O($_)���o�͂��܂�: ${OutEvtx}"
    wevtutil.exe epl $_ $OutEvtx /q:"*[System[TimeCreated[@SystemTime>='${StartDate}T15:00:00.000Z' and @SystemTime<='${EndDate}T15:00:00.000Z']]]"
    if (-not $?) {
        logger -Level ERROR "���O�o�͂Ɏ��s���܂���: $OutEvtx"
        exit 1
    }

    #########################
    # Evtx -> Txt �ϊ�
    #########################
    $OutTxt = $LogPath + $EndDate + ".txt"
    logger "Evtx���O($_)���e�L�X�g�ɕϊ����܂�: ${OutTxt}"
    wevtutil.exe qe $OutEvtx /lf /f:text /rd:false | Out-File $OutTxt
    # .\logparser.exe -i:Evtx -o:CSV "select * into $OutTxt from $OutEvtx"
    if (-not $?) {
        logger -Level ERROR "���O�ϊ��Ɏ��s���܂���: $OutTxt"
        exit 1
    }

    #########################
    # Evtx, Txt ���܂Ƃ߂Ĉ��k
    #########################
    $OutZip = $LogPath + $EndDate + ".zip"
    logger "���k���܂�: $OutZip"
    Compress-Archive -Path $OutEvtx, $OutTxt -DestinationPath $OutZip -Update # ���ɑ��݂���ꍇ�͒ǉ�
    # .\7z.exe a $OutZip $OutEvtx $OutTxt # ���ɑ��݂���ꍇ�͒ǉ�
    if (-not $?) {
        logger -Level ERROR "���k�Ɏ��s���܂���: $OutZip"
        exit 1
    }

    #########################
    # Evtx, Txt ���폜
    #########################
    # ���k�����������ꍇ
    Get-Item -Path $LogPath*.txt, $LogPath*.evtx | ForEach-Object {
        $path = $_.FullName
        logger "�폜���܂�: $path"
        Remove-Item -Force $path
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
