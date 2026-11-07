param(
  [string]$SdkRoot = $env:DEVECO_SDK_HOME,
  [string[]]$Architectures = @('arm64-v8a', 'x86_64')
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$SdkRoot) { throw 'Set DEVECO_SDK_HOME or pass -SdkRoot to the installed HarmonyOS SDK.' }
$native = Join-Path $SdkRoot 'default/openharmony/native'
$cmake = Join-Path $native 'build-tools/cmake/bin/cmake.exe'
$source = Join-Path $repo '.regression/vendor/MNN'
$pin = '6b1db4c2eacf8193e6b7a1841acb6e31a1938e82'
if (!(Test-Path $source)) {
  & git clone --depth 1 --branch 3.4.1 https://github.com/alibaba/MNN.git $source
  if ($LASTEXITCODE) { throw 'MNN clone failed' }
}
$revision = & git -C $source rev-parse HEAD
if ($revision.Trim() -ne $pin) { throw 'Unexpected MNN revision; existing source has been preserved.' }
$patch = Join-Path $PSScriptRoot 'mnn-legacy-tied-embedding.patch'
& git -C $source apply --reverse --check $patch 2>$null
if ($LASTEXITCODE) {
  & git -C $source apply --check $patch
  if ($LASTEXITCODE) { throw 'MNN patch does not apply; inspect existing changes.' }
  & git -C $source apply $patch
  if ($LASTEXITCODE) { throw 'MNN patch failed' }
}
foreach ($architecture in $Architectures) {
  if ($architecture -notin @('arm64-v8a', 'x86_64')) { throw 'Unsupported ABI' }
  $build = Join-Path $repo ".regression/mnn-runtime-$architecture"
  & $cmake -S $source -B $build -G Ninja "-DCMAKE_MAKE_PROGRAM=$native/build-tools/cmake/bin/ninja.exe" `
    "-DCMAKE_TOOLCHAIN_FILE=$native/build/cmake/ohos.toolchain.cmake" "-DOHOS_ARCH=$architecture" `
    -DOHOS_PLATFORM=OHOS -DCMAKE_BUILD_TYPE=Release -DMNN_BUILD_SHARED_LIBS=ON -DMNN_SEP_BUILD=OFF `
    -DMNN_BUILD_LLM=ON -DMNN_LLM_BUILD_DEMO=OFF -DMNN_BUILD_TOOLS=OFF -DMNN_USE_LOGCAT=OFF `
    -DMNN_OPENMP=OFF -DLLM_SUPPORT_HTTP_RESOURCE=OFF -DMNN_CPU_WEIGHT_DEQUANT_GEMM=ON
  if ($LASTEXITCODE) { throw 'MNN configure failed' }
  & $cmake --build $build --target MNN -j 6
  if ($LASTEXITCODE) { throw 'MNN build failed' }
  $destination = Join-Path $repo "entry/libs/$architecture"
  New-Item -ItemType Directory -Force $destination | Out-Null
  Copy-Item -LiteralPath "$build/libMNN.so" -Destination $destination
}
Write-Host 'Native runtimes prepared. Run python scripts/prepare-xiaoan-model.py --bundle to prepare verified model resources.'
