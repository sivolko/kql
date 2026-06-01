# KQL Detection Queries

Microsoft Defender for Endpoint (MDE) and Microsoft Sentinel KQL queries for threat hunting and security detection.

---

## Repository Structure

```
endpoint-ai-detection/    # Detecting local AI/LLM workloads on endpoints
scripts/                  # Intune Custom Compliance PowerShell scripts
```

---

## endpoint-ai-detection

Detection coverage for every class of AI/ML workload running on managed endpoints — local LLM runtimes, Python inference stacks, image generation, speech models, agent frameworks, and cloud API clients.

| File | Detection Target |
|---|---|
| `01-llm-runtime-processes.kql` | Known binaries + Python ML framework args |
| `02-model-weight-files.kql` | .gguf, .safetensors, .onnx, .pt and other weight formats |
| `03-modelhub-download-traffic.kql` | Outbound to HuggingFace, CivitAI, Ollama registry |
| `04-cloud-ai-api-outbound.kql` | API calls to OpenAI, Anthropic, Mistral, Bedrock, Cohere, etc. |
| `05-inference-server-ports.kql` | Local port bindings for all inference server runtimes |
| `06-python-package-installs.kql` | pip/conda install events for AI/ML packages |
| `07-cuda-library-loads.kql` | CUDA, DirectML, ROCm, ONNX Runtime, OpenVINO DLL loads |
| `08-docker-ai-containers.kql` | Docker run with GPU passthrough or known AI images |
| `09-wsl2-gpu-passthrough.kql` | nvidia-smi / ML workloads inside WSL2 |
| `10-high-memory-processes.kql` | Processes with >3GB working set (model loading indicator) |
| `11-gpu-inventory-tvm.kql` | GPU-capable device inventory via Defender TVM |

---

## scripts

| File | Purpose |
|---|---|
| `AIDetection_ComplianceProbe.ps1` | Full-sweep Intune compliance script: GPU util, running runtimes, model files, pip packages, open ports |
| `CustomCompliance_LocalAI_GPU.ps1` | Lightweight GPU utilization probe for Intune custom compliance policy |

---

## Platform

- Microsoft Defender for Endpoint (MDE) — Advanced Hunting
- Microsoft Sentinel — with MDE connector
- Microsoft Intune — Custom Compliance Policies

All KQL queries use standard MDE schema tables. For Sentinel, add `TenantId` scoping and use the connector-prefixed table aliases.

---

## Author

[Shubhendu Shubham](https://hugs4bugs.me) — Security Architect
