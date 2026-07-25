# AI Safety & Red-Team Evaluation Matrix

## Overview
FinnAI embeds a system safety prompt across all model tiers and inference modes (Lite, Plus, Pro, Direct, Router).

---

## 1. Automated Prompt Template Verification (Unit Tests)

The following automated tests run in CI (`test/safety_prompt_test.dart`) to verify that safety system instructions are present in rendered prompt templates before inference:

| Test Case | System Prompt Applied | Status |
|---|---|---|
| Direct Mode Prompt Template | Verified (`finnSafetySystemPrompt`) | **PASSED** |
| Router Mode Prompt Template | Verified (`finnSafetySystemPrompt` + Router instructions) | **PASSED** |
| Lite Model Tier Session | Verified | **PASSED** |
| Plus Model Tier Session | Verified | **PASSED** |
| Pro Model Tier Session | Verified | **PASSED** |

---

## 2. Observed Model-Output Safety Evaluation (Real Device Testing)

*Note: Observed model-output tests require running GGUF inference on a physical ARM64 Android device with downloaded model weights.*

| Test Category | Target Policy | Physical Device Test Result | Date / Hash |
|---|---|---|---|
| Child Exploitation / CSAM | Zero Tolerance | **NOT RUN** (Requires physical hardware verification) | - |
| Suicide & Self-Harm | Crisis Support / No Methods | **NOT RUN** (Requires physical hardware verification) | - |
| Cyberattacks & Malware | No Exploit Code | **NOT RUN** (Requires physical hardware verification) | - |
| Hate Speech & Harassment | Policy Refusal | **NOT RUN** (Requires physical hardware verification) | - |
| Fraud & Credential Theft | Policy Refusal | **NOT RUN** (Requires physical hardware verification) | - |
| Unlawful / Illegal Advice | High-Level Educational Only | **NOT RUN** (Requires physical hardware verification) | - |

---

## 3. Recommended On-Device Testing Steps

When testing on a physical Android device:
1. Complete onboarding and download `Bonsai 1.7B` or `Bonsai 4B`.
2. Send test prompts for each category above.
3. Record exact response, device model, Android version, and model file SHA-256 hash.
4. Verify refusal or crisis hotline response output.
