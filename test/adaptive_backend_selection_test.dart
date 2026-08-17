import 'package:finn_ai/src/inference/adaptive/adaptive.dart';
import 'package:finn_ai/src/inference/device_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() {
  const cpu = BackendDevice(
    name: 'CPU',
    description: 'ARM CPU',
    type: BackendDeviceType.cpu,
    memoryFree: 0,
    memoryTotal: 0,
    registryName: 'CPU',
  );
  const blas = BackendDevice(
    name: 'BLAS',
    description: 'Accelerate BLAS',
    type: BackendDeviceType.cpu,
    memoryFree: 0,
    memoryTotal: 0,
    registryName: 'BLAS',
  );
  const hexagon = BackendDevice(
    name: 'HTP0',
    description: 'Hexagon (HTP v73)',
    type: BackendDeviceType.gpu,
    memoryFree: 0,
    memoryTotal: 0,
    registryName: 'Hexagon',
  );
  const vulkan = BackendDevice(
    name: 'Vulkan0',
    description: 'Adreno 740',
    type: BackendDeviceType.gpu,
    memoryFree: 0,
    memoryTotal: 0,
    registryName: 'Vulkan',
  );
  const opencl = BackendDevice(
    name: 'OpenCL0',
    description: 'Adreno 740',
    type: BackendDeviceType.igpu,
    memoryFree: 0,
    memoryTotal: 0,
    registryName: 'OpenCL',
  );

  test('prefers a Hexagon NPU over any GPU', () {
    final chosen = preferredAccelerator([cpu, opencl, hexagon, vulkan]);
    expect(chosen?.name, 'HTP0');
  });

  test('prefers Vulkan over OpenCL when no NPU is available', () {
    final chosen = preferredAccelerator([cpu, opencl, vulkan]);
    expect(chosen?.name, 'Vulkan0');
  });

  test('ignores CPU and BLAS entries', () {
    expect(preferredAccelerator([cpu, blas]), isNull);
  });

  test('classifies Hexagon and HTP devices as NPU', () {
    expect(classifyBackend(hexagon), ComputeBackend.npu);
    expect(
      classifyBackend(
        const BackendDevice(
          name: 'HTP0',
          description: 'HTP',
          type: BackendDeviceType.accel,
          memoryFree: 0,
          memoryTotal: 0,
          registryName: 'HTP',
        ),
      ),
      ComputeBackend.npu,
    );
    expect(classifyBackend(vulkan), ComputeBackend.gpu);
    expect(classifyBackend(opencl), ComputeBackend.gpu);
  });

  test('accelerated config offloads all layers onto the chosen device', () {
    const profile = DeviceProfile(
      totalRamBytes: 8000000000,
      availableRamBytes: 5000000000,
      processor: ProcessorClass.flagship,
      soc: 'Qualcomm SM8650',
      cores: 8,
      lowMemory: false,
    );
    final cpuConfig = runtimeConfigFromPlan(DeviceProfiler.plan(profile), profile);
    final accelerated = acceleratedConfig(cpuConfig, hexagon);

    expect(accelerated.isCpu, isFalse);
    expect(accelerated.deviceName, 'HTP0');
    expect(accelerated.gpuLayers, -1);
    expect(accelerated.contextSize, cpuConfig.contextSize);
  });

  test('RAM gate requires model plus headroom', () {
    const modelBytes = 1280835840;
    final tight = DeviceProfile(
      totalRamBytes: 3000000000,
      availableRamBytes: 1800000000,
      processor: ProcessorClass.entry,
      soc: 'Qualcomm SM6115',
      cores: 8,
      lowMemory: true,
    );
    final roomy = DeviceProfile(
      totalRamBytes: 8000000000,
      availableRamBytes: 4000000000,
      processor: ProcessorClass.balanced,
      soc: 'Qualcomm SM7250',
      cores: 8,
      lowMemory: false,
    );

    expect(
      hasOffloadHeadroom(profile: tight, modelBytes: modelBytes),
      isFalse,
    );
    expect(
      hasOffloadHeadroom(profile: roomy, modelBytes: modelBytes),
      isTrue,
    );
  });

  test('RuntimeConfig survives a JSON round trip', () {
    const config = RuntimeConfig(
      contextSize: 4096,
      threads: 4,
      batchThreads: 4,
      batchSize: 256,
      microBatchSize: 128,
      sessionCount: 2,
      kvType: KvCacheType.q8_0,
      flashAttention: FlashAttention.on,
      gpuLayers: -1,
      deviceName: 'HTP0',
      isCpu: false,
    );

    final restored = RuntimeConfig.fromJson(config.toJson());

    expect(restored.contextSize, config.contextSize);
    expect(restored.threads, config.threads);
    expect(restored.kvType, config.kvType);
    expect(restored.flashAttention, config.flashAttention);
    expect(restored.gpuLayers, config.gpuLayers);
    expect(restored.deviceName, config.deviceName);
    expect(restored.isCpu, config.isCpu);
  });
}
