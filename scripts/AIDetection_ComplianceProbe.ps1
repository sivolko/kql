<#
.SYNOPSIS
    Full-sweep AI/LLM workload detection probe for Intune Custom Compliance.

.DESCRIPTION
    Detects local AI workloads across all signal layers:
    - NVIDIA GPU utilization via nvidia-smi
    - Running LLM runtime processes
    - Model weight file presence (.gguf, .safetensors, .onnx, etc.)
    - HuggingFace, Ollama, and LM Studio cache directories
    - AI/ML Python packages (pip list)
    - Local inference server ports

    Returns JSON consumed by Intune Custom Compliance rule engine.
    Deploy as a Custom Compliance Policy script (Discovery script).

.NOTES
    Run context : SYSTEM account
    Platform    : Windows 10/11 managed endpoint
    Schedule    : Every 8 hours recommended
#>

$result = @{
    GPUPresent           = $false
    GPUUtilPct           = 0
    GPUMemUsedMB         = 0
    GPUMemTotalMB        = 0
    LLMRuntimeRunning    = $false
    LLMRuntimeNames      = @()
    ModelFilesFound      = $false
    ModelFilePaths       = @()
    HFCacheFound         = $false
    OllamaCacheFound     = $false
    LMStudioCacheFound   = $false
    AIPackagesInstalled  = @()
    LocalPortsOpen       = @()
}

# ── NVIDIA GPU via nvidia-smi ──────────────────────────────────────────────────
$nvSmi = Get-ChildItem "C:\Windows\System32\DriverStore\FileRepository" `
    -Filter "nvidia-smi.exe" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName

if ($nvSmi) {
    $gpuOut = & $nvSmi --query-gpu=utilization.gpu,memory.used,memory.total `
        --format=csv,noheader,nounits 2>$null
    if ($gpuOut) {
        $v = ($gpuOut -split ",") | ForEach-Object { $_.Trim() }
        $result.GPUPresent    = $true
        $result.GPUUtilPct    = [int]$v[0]
        $result.GPUMemUsedMB  = [int]$v[1]
        $result.GPUMemTotalMB = [int]$v[2]
    }
}

# ── Running LLM processes ──────────────────────────────────────────────────────
$llmNames = @(
    "ollama", "llama", "llama-server", "llama-cli",
    "koboldcpp", "gpt4all", "lm_studio", "jan",
    "localai", "llamafile", "tabby",
    "text-generation-webui", "comfyui", "invokeai",
    "whisper", "vllm", "sglang", "openwebui", "msty"
)

$running = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $pName = $_.ProcessName.ToLower()
    $llmNames | Where-Object { $pName -like "*$_*" }
}

$result.LLMRuntimeRunning = ($running.Count -gt 0)
$result.LLMRuntimeNames   = @($running.ProcessName | Select-Object -Unique)

# ── Model cache directories ────────────────────────────────────────────────────
$userProfile = [System.Environment]::GetFolderPath("UserProfile")
$localApp    = [System.Environment]::GetFolderPath("LocalApplicationData")

$hfCache   = Join-Path $userProfile ".cache\huggingface"
$olCache   = Join-Path $userProfile ".ollama\models"
$lmsCache  = Join-Path $localApp   "LM Studio\models"

$result.HFCacheFound       = (Test-Path $hfCache)
$result.OllamaCacheFound   = (Test-Path $olCache)
$result.LMStudioCacheFound = (Test-Path $lmsCache)

# ── Model weight files (spot-check common locations) ──────────────────────────
$searchRoots = @(
    (Join-Path $userProfile "Downloads"),
    (Join-Path $userProfile "Documents"),
    (Join-Path $userProfile "Desktop"),
    $hfCache, $olCache, $lmsCache,
    "C:\models", "C:\ai", "C:\llm", "C:\ml"
) | Where-Object { Test-Path $_ }

$modelExts = @("*.gguf", "*.ggml", "*.safetensors", "*.onnx", "*.mlmodel")
$sizeThreshold = 100MB

$found = foreach ($root in $searchRoots) {
    foreach ($ext in $modelExts) {
        Get-ChildItem -Path $root -Filter $ext -Recurse `
            -ErrorAction SilentlyContinue -Depth 6 |
            Where-Object { $_.Length -gt $sizeThreshold } |
            Select-Object -ExpandProperty FullName -First 3
    }
}

$result.ModelFilesFound = ($null -ne $found -and @($found).Count -gt 0)
$result.ModelFilePaths  = @($found | Select-Object -Unique -First 5)

# ── AI Python packages via pip list ───────────────────────────────────────────
$aiPackageList = @(
    "torch", "tensorflow", "jax", "transformers", "diffusers",
    "llama-cpp-python", "ctransformers", "exllamav2", "auto-gptq", "autoawq",
    "bitsandbytes", "vllm", "langchain", "llama-index",
    "openai", "anthropic", "cohere", "mistralai",
    "faster-whisper", "openai-whisper", "TTS",
    "gradio", "streamlit", "ollama",
    "huggingface-hub", "accelerate", "onnxruntime", "onnxruntime-gpu"
)

try {
    $pipOut = python -m pip list --format=columns 2>$null
    if ($pipOut) {
        $result.AIPackagesInstalled = @($aiPackageList | Where-Object {
            $pkg = $_
            $pipOut | Where-Object { $_ -imatch "^$([regex]::Escape($pkg))\s" }
        })
    }
} catch { }

# ── Local inference ports ─────────────────────────────────────────────────────
$targetPorts = @(
    11434,  # Ollama
    1234,   # LM Studio
    1337,   # Jan.ai
    7860,   # Gradio
    8000,   # vLLM / FastAPI / TGI
    8080,   # LocalAI / Tabby
    8888,   # Jupyter
    3000,   # OpenWebUI / Jan
    5000,   # Flask apps
    4891,   # GPT4All
    9000,   # Tabby alt
    8501    # Streamlit
)

try {
    $openPorts = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -in $targetPorts }
    $result.LocalPortsOpen = @($openPorts | Select-Object -ExpandProperty LocalPort | Sort-Object -Unique)
} catch { }

# ── Output ────────────────────────────────────────────────────────────────────
return $result | ConvertTo-Json -Compress
