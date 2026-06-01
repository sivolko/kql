<#
.SYNOPSIS
    Lightweight GPU utilization probe for Intune Custom Compliance policy.

.DESCRIPTION
    Reports GPU utilization percentage and memory via nvidia-smi.
    Flags known LLM runtime processes.
    Use this as the Discovery script for a Custom Compliance Policy
    with rules:
      - GPUUtilPct > 80  --> NonCompliant
      - SuspiciousProc == true --> NonCompliant

.NOTES
    Run context : SYSTEM account
    Platform    : Windows 10/11 with NVIDIA GPU
    Compliance  : Pair with Intune Custom Compliance remediation message
#>

$result = @{
    GPUAvailable   = $false
    GPUUtilPct     = 0
    GPUMemUsedMB   = 0
    GPUMemTotalMB  = 0
    SuspiciousProc = $false
    SuspiciousProcNames = @()
}

# Find nvidia-smi (path varies by driver version)
$nvSmi = Get-ChildItem "C:\Windows\System32\DriverStore\FileRepository" `
    -Filter "nvidia-smi.exe" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName

if ($nvSmi) {
    $gpuData = & $nvSmi --query-gpu=utilization.gpu,memory.used,memory.total `
        --format=csv,noheader,nounits 2>$null
    if ($gpuData) {
        $vals = ($gpuData -split ",") | ForEach-Object { $_.Trim() }
        $result.GPUAvailable  = $true
        $result.GPUUtilPct    = [int]$vals[0]
        $result.GPUMemUsedMB  = [int]$vals[1]
        $result.GPUMemTotalMB = [int]$vals[2]
    }
}

# Known LLM runtime process names
$llmProcs = @(
    "ollama", "llama", "koboldcpp", "gpt4all",
    "lm_studio", "jan", "localai", "llamafile",
    "vllm", "sglang", "tabby", "openwebui"
)

$running = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $n = $_.ProcessName.ToLower()
    $llmProcs | Where-Object { $n -like "*$_*" }
}

$result.SuspiciousProc      = ($running.Count -gt 0)
$result.SuspiciousProcNames = @($running.ProcessName | Select-Object -Unique)

return $result | ConvertTo-Json -Compress
