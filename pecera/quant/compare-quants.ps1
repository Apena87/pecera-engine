# Builds two stronger quants of Inkling-2-Mini next to mixB and measures all three against a Q8_0 reference.
# Run detached. Progress and results: pecera\results\quant-compare.log (last line DONE), per-step logs beside it.
#
# Candidates (blocks 22-23 stay IQ4_NL and run on the CPU in every file, non-expert tensors stay Q6_K):
#   mixB  blocks 0-5 IQ2_S, loop core 6-17 IQ3_XXS, 18-21 IQ3_XXS down + IQ2_S gate/up          (existing file)
#   mixC  every GPU-side expert IQ3_XXS (blocks 0-21)
#   mixS  mixB layout with the loop core raised to IQ3_S
# Quality: llama-perplexity --kl-divergence on 50 chunks of 512 tokens of wikitext-2 test, the measure the mixB card uses.
$ProgressPreference = 'SilentlyContinue'
$old = 'C:\Llama\inkling-fast'; $bf = "$old\bf16"; $models = "$old\models"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot); $res = "$root\pecera\results"
$log = "$res\quant-compare.log"; $py = "$env:USERPROFILE\anaconda3\python.exe"
$q = "$old\build\bin\llama-quantize.exe"; $ppl = "$old\build\bin\llama-perplexity.exe"
function L($m) { "$(Get-Date -Format T) $m" | Add-Content $log -Encoding ascii }
function Run($exe, $argList, $tag) {
  $p = Start-Process -FilePath $exe -ArgumentList $argList -WindowStyle Hidden -PassThru -Wait -RedirectStandardError "$res\quant-$tag.err.log" -RedirectStandardOutput "$res\quant-$tag.out.log"
  L "$tag exit $($p.ExitCode)"
}
"started $(Get-Date -Format s)" | Set-Content $log -Encoding ascii

# 1. wait for the BF16 download and its checksum
while (-not (Test-Path "$bf\download.done")) { Start-Sleep 15 }
$dl = (Get-Content "$bf\download.done" -Raw).Trim(); L "download: $dl"
if ($dl -notmatch 'missing 0 sha256 OK') { L 'STOP: download incomplete or checksum mismatch'; 'DONE' | Add-Content $log -Encoding ascii; exit 1 }
$src = "$bf\Inkling-2-Mini-BF16.gguf"; $im = "$bf\imatrix.gguf"

# 2. wikitext-2 raw test text
$wiki = "$bf\wiki.test.raw"
if (-not (Test-Path $wiki)) {
  $code = "import io, requests, pandas as pd; b = requests.get('https://huggingface.co/datasets/Salesforce/wikitext/resolve/main/wikitext-2-raw-v1/test-00000-of-00001.parquet', timeout=120).content; df = pd.read_parquet(io.BytesIO(b)); open(r'$wiki', 'w', encoding='utf-8', newline='').write(''.join(df['text']))"
  & $py -c $code 2> "$res\quant-wiki.err.log"
  L "wikitext bytes $((Get-Item $wiki -ErrorAction SilentlyContinue).Length)"
}

# 3. quantize: reference and the two candidates
$loops = '6|7|8|9|10|11|12|13|14|15|16|17'
$ref = "$bf\Inkling-2-Mini-Q8_0.gguf"
if (-not (Test-Path $ref)) { Run $q @("`"$src`"", "`"$ref`"", 'Q8_0', '24') 'q8'; L "Q8_0 GiB $([math]::Round((Get-Item $ref).Length/1GB,2))" }
$common = @('--pad-exps', '--imatrix', "`"$im`"", '--token-embedding-type', 'q8_0', '--output-tensor-type', 'q6_k')
$mixC = "$models\Inkling-2-Mini-mixC.gguf"
if (-not (Test-Path $mixC)) {
  Run $q ($common + @('--tensor-type', '"blk\.(22|23)\.ffn_.*_exps=iq4_nl"', '--tensor-type', '"ffn_.*_exps=iq3_xxs"', "`"$src`"", "`"$mixC.tmp`"", 'Q6_K', '24')) 'mixC'
  if (Test-Path "$mixC.tmp") { Rename-Item "$mixC.tmp" $mixC; L "mixC GiB $([math]::Round((Get-Item $mixC).Length/1GB,2))" }
}
$mixS = "$models\Inkling-2-Mini-mixS.gguf"
if (-not (Test-Path $mixS)) {
  Run $q ($common + @('--tensor-type', '"blk\.(22|23)\.ffn_.*_exps=iq4_nl"', '--tensor-type', "`"blk\.($loops)\.ffn_.*_exps=iq3_s`"",
    '--tensor-type', '"blk\.(18|19|20|21)\.ffn_down_exps=iq3_xxs"', '--tensor-type', '"ffn_.*_exps=iq2_s"', "`"$src`"", "`"$mixS.tmp`"", 'Q6_K', '24')) 'mixS'
  if (Test-Path "$mixS.tmp") { Rename-Item "$mixS.tmp" $mixS; L "mixS GiB $([math]::Round((Get-Item $mixS).Length/1GB,2))" }
}

# 4. reference logits from Q8_0. Seven loop-core blocks fit on the GPU, the other experts run on the CPU.
#    --no-op-offload: the old build returns NaN when loop-core experts sit on the CPU with op offload on.
$base = "$bf\q8.kld"
$pp = @('-f', "`"$wiki`"", '-c', '512', '-b', '512', '--chunks', '50', '-ngl', '99', '-fa', 'on', '-t', '16')
if (-not (Test-Path $base)) {
  Run $ppl (@('-m', "`"$ref`"") + $pp + @('-ot', '"blk\.(0|1|2|3|4|5|13|14|15|16|17|18|19|20|21|22|23)\.ffn_.*_exps=CPU"', '--no-op-offload', '--kl-divergence-base', "`"$base`"")) 'ref'
  L "reference logits GiB $([math]::Round((Get-Item $base -ErrorAction SilentlyContinue).Length/1GB,2))"
  Get-Content "$res\quant-ref.out.log", "$res\quant-ref.err.log" -ErrorAction SilentlyContinue | Select-String -Pattern 'Final estimate|nan' | Select-Object -First 3 | ForEach-Object { L "ref | $($_.Line.Trim())" }
}

# 5. KL divergence of each file against the reference, standard placement
if (Test-Path $base) {
  foreach ($m in @(@('mixB', "$models\Inkling-2-Mini-mixB.gguf"), @('mixC', $mixC), @('mixS', $mixS))) {
    if (-not (Test-Path $m[1])) { L "$($m[0]) missing"; continue }
    Run $ppl (@('-m', "`"$($m[1])`"") + $pp + @('-ot', '"blk\.(22|23)\.ffn_.*_exps=CPU"', '--kl-divergence-base', "`"$base`"", '--kl-divergence')) "kld-$($m[0])"
    Get-Content "$res\quant-kld-$($m[0]).out.log", "$res\quant-kld-$($m[0]).err.log" -ErrorAction SilentlyContinue |
      Select-String -Pattern 'Mean\s+KLD|Same top p|Mean PPL\(Q\)\s|Mean PPL\(Q\)/PPL\(base\)|Maximum KLD|99\.0%\s+KLD' |
      ForEach-Object { L "$($m[0]) | $($_.Line.Trim())" }
  }
}

# 6. speed and VRAM of each file on the pecera build, 64k, standard placement
$srv = "$root\build-ugbun\bin\llama-server.exe"; if (Test-Path "$root\build\bin\llama-server.exe") { $srv = "$root\build\bin\llama-server.exe" }
foreach ($m in @(@('mixB', "$models\Inkling-2-Mini-mixB.gguf"), @('mixC', $mixC), @('mixS', $mixS))) {
  if (-not (Test-Path $m[1])) { continue }
  $tag = "quant-speed-$($m[0])"
  Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$root\pecera\bench.ps1", '-Exe', $srv, '-Tag', $tag, '-Model', $m[1], '-Ctx', '65536' -WindowStyle Hidden -Wait
  Get-Content "$res\$tag.txt" -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(up=|greedy run 3|chat run|gpu_after)' } | ForEach-Object { L "$($m[0]) | $_" }
}
'DONE' | Add-Content $log -Encoding ascii
