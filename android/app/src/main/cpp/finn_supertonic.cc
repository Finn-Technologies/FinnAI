// A small C wrapper that runs the four Supertonic ONNX models for one chunk of
// text. Everything language-specific (normalising text, mapping it to ids,
// reading voice styles) is done in Dart; this file only does the numerical part
// that must be fast: duration -> text encoding -> denoising loop -> vocoder.
//
// The algorithm is the one in Supertone's reference implementation
// (py/helper.py, MIT licence). It links ONNX Runtime (MIT) dynamically.
#include <onnxruntime_cxx_api.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <random>
#include <string>
#include <vector>

namespace {

struct FinnTts {
  FinnTts(const std::string& dir, int threads)
      : env(ORT_LOGGING_LEVEL_WARNING, "finn_tts"),
        options(MakeOptions(threads)),
        duration(env, (dir + "/duration_predictor.onnx").c_str(), options),
        encoder(env, (dir + "/text_encoder.onnx").c_str(), options),
        estimator(env, (dir + "/vector_estimator.onnx").c_str(), options),
        vocoder(env, (dir + "/vocoder.onnx").c_str(), options),
        rng(std::random_device{}()) {}

  static Ort::SessionOptions MakeOptions(int threads) {
    Ort::SessionOptions o;
    o.SetIntraOpNumThreads(threads);
    o.SetInterOpNumThreads(1);
    o.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);
    return o;
  }

  Ort::Env env;
  Ort::SessionOptions options;
  Ort::Session duration;
  Ort::Session encoder;
  Ort::Session estimator;
  Ort::Session vocoder;
  std::mt19937 rng;
};

void SetError(char* error, int length, const std::string& message) {
  if (error == nullptr || length <= 0) return;
  std::snprintf(error, static_cast<size_t>(length), "%s", message.c_str());
}

}  // namespace

extern "C" {

__attribute__((visibility("default"))) void* finn_tts_create(
    const char* directory, int threads, char* error, int error_length) {
  try {
    return new FinnTts(directory, std::max(1, threads));
  } catch (const std::exception& e) {
    SetError(error, error_length, e.what());
    return nullptr;
  }
}

__attribute__((visibility("default"))) void finn_tts_destroy(void* handle) {
  delete static_cast<FinnTts*>(handle);
}

__attribute__((visibility("default"))) void finn_tts_free(float* samples) {
  delete[] samples;
}

// Returns 0 on success. On success *out is a new[] array the caller frees with
// finn_tts_free; *out_length is its length and *out_seconds the speech length
// (the vocoder pads, so only that much of the audio is speech).
__attribute__((visibility("default"))) int finn_tts_infer(
    void* handle, const int64_t* text_ids, int text_length,
    const float* style_ttl, int64_t ttl_dim1, int64_t ttl_dim2,
    const float* style_dp, int64_t dp_dim1, int64_t dp_dim2, int total_steps,
    float speed, int sample_rate, int chunk_size, int latent_dim, float** out,
    int* out_length, float* out_seconds, char* error, int error_length) {
  try {
    auto* tts = static_cast<FinnTts*>(handle);
    Ort::MemoryInfo memory =
        Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);

    const int64_t ids_shape[2] = {1, text_length};
    std::vector<int64_t> ids(text_ids, text_ids + text_length);
    Ort::Value ids_value = Ort::Value::CreateTensor<int64_t>(
        memory, ids.data(), ids.size(), ids_shape, 2);

    std::vector<float> mask(static_cast<size_t>(text_length), 1.0f);
    const int64_t mask_shape[3] = {1, 1, text_length};
    Ort::Value mask_value = Ort::Value::CreateTensor<float>(
        memory, mask.data(), mask.size(), mask_shape, 3);

    const int64_t ttl_shape[3] = {1, ttl_dim1, ttl_dim2};
    Ort::Value ttl_value = Ort::Value::CreateTensor<float>(
        memory, const_cast<float*>(style_ttl),
        static_cast<size_t>(ttl_dim1 * ttl_dim2), ttl_shape, 3);
    const int64_t dp_shape[3] = {1, dp_dim1, dp_dim2};
    Ort::Value dp_value = Ort::Value::CreateTensor<float>(
        memory, const_cast<float*>(style_dp),
        static_cast<size_t>(dp_dim1 * dp_dim2), dp_shape, 3);

    // 1. How long the speech will be.
    const char* dp_in[] = {"text_ids", "style_dp", "text_mask"};
    const char* dp_out[] = {nullptr};
    Ort::AllocatorWithDefaultOptions allocator;
    auto dp_out_name = tts->duration.GetOutputNameAllocated(0, allocator);
    dp_out[0] = dp_out_name.get();
    Ort::Value dp_inputs[] = {std::move(ids_value), std::move(dp_value),
                              std::move(mask_value)};
    auto dp_result = tts->duration.Run(Ort::RunOptions{nullptr}, dp_in,
                                       dp_inputs, 3, dp_out, 1);
    float seconds = dp_result[0].GetTensorData<float>()[0] / speed;
    if (!(seconds > 0.0f) || seconds > 120.0f) {
      SetError(error, error_length, "implausible duration");
      return 2;
    }

    // The inputs were moved into the call above; build them again.
    Ort::Value ids2 = Ort::Value::CreateTensor<int64_t>(memory, ids.data(),
                                                        ids.size(), ids_shape, 2);
    Ort::Value mask2 = Ort::Value::CreateTensor<float>(memory, mask.data(),
                                                       mask.size(), mask_shape, 3);
    Ort::Value ttl2 = Ort::Value::CreateTensor<float>(
        memory, const_cast<float*>(style_ttl),
        static_cast<size_t>(ttl_dim1 * ttl_dim2), ttl_shape, 3);

    // 2. Encode the text.
    const char* enc_in[] = {"text_ids", "style_ttl", "text_mask"};
    auto enc_out_name = tts->encoder.GetOutputNameAllocated(0, allocator);
    const char* enc_out[] = {enc_out_name.get()};
    Ort::Value enc_inputs[] = {std::move(ids2), std::move(ttl2),
                               std::move(mask2)};
    auto enc_result = tts->encoder.Run(Ort::RunOptions{nullptr}, enc_in,
                                       enc_inputs, 3, enc_out, 1);
    Ort::Value text_embedding = std::move(enc_result[0]);

    // 3. Start from noise the length of the speech, denoise it step by step.
    const int64_t wav_length = static_cast<int64_t>(seconds * sample_rate);
    const int64_t latent_length = (wav_length + chunk_size - 1) / chunk_size;
    const size_t latent_count = static_cast<size_t>(latent_dim * latent_length);
    std::vector<float> latent(latent_count);
    std::normal_distribution<float> normal(0.0f, 1.0f);
    for (auto& v : latent) v = normal(tts->rng);
    std::vector<float> latent_mask(static_cast<size_t>(latent_length), 1.0f);
    const int64_t latent_shape[3] = {1, latent_dim, latent_length};
    const int64_t latent_mask_shape[3] = {1, 1, latent_length};
    const int64_t scalar_shape[1] = {1};

    const char* est_in[] = {"noisy_latent", "text_emb",    "style_ttl",
                            "text_mask",    "latent_mask", "current_step",
                            "total_step"};
    auto est_out_name = tts->estimator.GetOutputNameAllocated(0, allocator);
    const char* est_out[] = {est_out_name.get()};
    float total = static_cast<float>(total_steps);
    const auto embedding_info = text_embedding.GetTensorTypeAndShapeInfo();
    const std::vector<int64_t> embedding_shape = embedding_info.GetShape();
    const size_t embedding_count = embedding_info.GetElementCount();
    const float* embedding_data = text_embedding.GetTensorData<float>();

    for (int step = 0; step < total_steps; ++step) {
      float current = static_cast<float>(step);
      Ort::Value inputs[7] = {
          Ort::Value::CreateTensor<float>(memory, latent.data(), latent.size(),
                                          latent_shape, 3),
          Ort::Value::CreateTensor(
              memory, const_cast<float*>(embedding_data),
              embedding_count * sizeof(float), embedding_shape.data(),
              embedding_shape.size(), ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT),
          Ort::Value::CreateTensor<float>(
              memory, const_cast<float*>(style_ttl),
              static_cast<size_t>(ttl_dim1 * ttl_dim2), ttl_shape, 3),
          Ort::Value::CreateTensor<float>(memory, mask.data(), mask.size(),
                                          mask_shape, 3),
          Ort::Value::CreateTensor<float>(memory, latent_mask.data(),
                                          latent_mask.size(),
                                          latent_mask_shape, 3),
          Ort::Value::CreateTensor<float>(memory, &current, 1, scalar_shape, 1),
          Ort::Value::CreateTensor<float>(memory, &total, 1, scalar_shape, 1)};
      auto result = tts->estimator.Run(Ort::RunOptions{nullptr}, est_in, inputs,
                                       7, est_out, 1);
      const float* next = result[0].GetTensorData<float>();
      std::copy(next, next + latent_count, latent.begin());
    }

    // 4. Turn the latent into audio.
    const char* voc_in[] = {"latent"};
    auto voc_out_name = tts->vocoder.GetOutputNameAllocated(0, allocator);
    const char* voc_out[] = {voc_out_name.get()};
    Ort::Value voc_inputs[] = {Ort::Value::CreateTensor<float>(
        memory, latent.data(), latent.size(), latent_shape, 3)};
    auto wav = tts->vocoder.Run(Ort::RunOptions{nullptr}, voc_in, voc_inputs, 1,
                                voc_out, 1);
    const size_t produced = wav[0].GetTensorTypeAndShapeInfo().GetElementCount();
    const size_t keep = std::min<size_t>(produced, static_cast<size_t>(wav_length));
    float* samples = new float[keep];
    std::memcpy(samples, wav[0].GetTensorData<float>(), keep * sizeof(float));
    *out = samples;
    *out_length = static_cast<int>(keep);
    *out_seconds = seconds;
    return 0;
  } catch (const std::exception& e) {
    SetError(error, error_length, e.what());
    return 1;
  }
}

}  // extern "C"
