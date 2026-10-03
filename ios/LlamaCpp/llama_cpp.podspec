#
# FinnAI-local podspec for the prebuilt llama.cpp xcframework on iOS.
#
# The framework binary comes from the pinned llama_cpp_dart release asset
# (see tool/rebuild_llama_ios_xcframework.sh) and is intentionally NOT
# committed: ios/.gitignore excludes LlamaCpp/llama.xcframework. Run the
# script once per checkout to fetch it.
#
# CocoaPods embeds + signs the dynamic framework; dyld loads it at launch
# so its symbols are visible to DynamicLibrary.process(), which is what
# LlamaEngine.spawnFromProcess() (used on iOS) resolves against.
#
Pod::Spec.new do |s|
  s.name             = 'llama_cpp'
  s.version          = '0.9.0-dev.9'
  s.summary          = 'llama.cpp xcframework for FinnAI on iOS.'
  s.description      = <<-DESC
    Prebuilt llama.cpp + ggml + mtmd as an xcframework, matching the
    llama_cpp_dart Dart package vendored in third_party/llama_cpp_dart.
    iOS slices only are used by this app (ios-arm64 device slice).
  DESC
  s.homepage         = 'https://github.com/netdur/llama_cpp_dart'
  s.license          = { :type => 'MIT' }
  s.author           = { 'netdur' => 'noreply@netdur.dev' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '15.0'

  s.vendored_frameworks = 'llama.xcframework'

  s.frameworks = 'Metal', 'MetalKit', 'Foundation', 'Accelerate'
end
