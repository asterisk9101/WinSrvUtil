###############################################################################
# �p�t�H�[�}���X���O���[�e�[�V����
###############################################################################
Param(
    [string]$LogDir = ".",
    [string]$DataCollectorSetName = $Env:COMPUTERNAME,
    [int]$Rotate = 65
)
$ErrorActionPreference = "continue"

# ���s�t�@�C�����g�̏��
$item = Get-Item $MyInvocation.MyCommand.Path
$here = $item.Directory
$basename = $item.BaseName

# ���ʊ֐��̓ǂݍ���
. $here\common\PSLogger.ps1

# ���s���O�̏�����
$logpath = Join-Path $logdir ($basename + ".log")
New-Logger -Path $logpath -Rotate $Rotate -ToScreen


logger "�p�t�H�[�}���X���O���[�e�[�V�����J�n=================================================="

$DCS = New-Object -ComObject PLA.DataCollectorSet
$DCS.query($DataCollectorSetName, "localhost")
$RootPath = $DCS.RootPath -replace '%systemdrive%', $Env:SystemDrive

if (-not (Test-Path $RootPath)) {
    logger -level ERROR "�f�[�^�R���N�^�Z�b�g�̃��[�g�p�X��������܂���: ${DataCollectorSetName}"
    exit 1
}

##########################
# �p�t�H�[�}���X���O��~
##########################
logger "�f�[�^�R���N�^�Z�b�g���~���܂�: ${DataCollectorSetName}"
$DCS.stop($True)
if ($DCS.status -ne 0) {
    logger -level ERROR "�f�[�^�R���N�^�Z�b�g����~���Ă��܂���: ${DataCollectorSetName}"
}

##########################
# �ϊ�
##########################
# �ϊ�����Ă��Ȃ� blg �t�@�C������������
#$blgfiles = Get-ChildItem -File -Recurse $RootPath | Group-Object BaseName | Where-Object Count -eq 1 | ForEach-Object Group | Where-Object Extension -eq ".blg"
#$blgfiles | ForEach-Object {
#    $outpath = Join-Path $_.Directory ($_.BaseName + ".csv")
#    relog $_.FullName -f CSV -o $outpath
#}

##########################
# ���[�e�[�V����
##########################
Get-ChildItem -File -Recurse $RootPath | Sort-Object -Descending LastWriteTime | Select-Object -Skip $Rotate | ForEach-Object {
    $path = $_.FullName
    logger "�폜���܂�: $path"
    Remove-Item -Force $path
}

##########################
# �p�t�H�[�}���X���O�J�n
##########################
logger "�f�[�^�R���N�^�Z�b�g���J�n���܂�: ${DataCollectorSetName}"
$DCS.start($True)
if ($DCS.status -ne 1) {
    logger -level ERROR "�f�[�^�R���N�^�Z�b�g���J�n���Ă��܂���: ${DataCollectorSetName}"
    exit 1
}

# COM �I�u�W�F�N�g�̊J��
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($DCS) | Out-Null

logger "�p�t�H�[�}���X���O���[�e�[�V�����I��=================================================="
exit 0
