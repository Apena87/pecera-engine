# Roadmap item 3: lower-bit dense weights. Same expert recipe as mixC (experts IQ3_XXS, blocks 22-23 IQ4_NL),
# only the base type of the non-expert tensors and the output head change. Quantizer: the inkling-fast build,
# which has --pad-exps. Quality: KLD against the Q8_0 reference (50 x 512 wikitext-2). Speed and VRAM: bench.ps1
# on the next build at 64k with blocks 20-23 on the CPU (daily placement).
# Step 1 (quantize) runs now. Steps 2-3 wait for -WaitFile so they do not share the GPU with another job.
param([string]$WaitFile = '')
$ProgressPreference = 'SilentlyContinue'
$old = 'C:\Llama\inkling-fast'; $bf = "$old\bf16"; $models = "$old\models"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot); $res = "$root\pecera\results"
$log = "$res\dense-sweep.log"
$q = "$old\build\bin\llama-quantize.exe"; $ppl = "$root\build\bin\llama-perplexity.exe"; $srv = "$root\build\bin\llama-server.exe"
function L($m) { "$(Get-Date -Format T) $m" | Add-Content $log -Encoding ascii }
function Run($exe, $argList, $tag) {
  $p = Start-Process -FilePath $exe -ArgumentList $argList -WindowStyle Hidden -PassThru -Wait -RedirectStandardError "$res\$tag.err.log" -RedirectStandardOutput "$res\$tag.out.log"
  L "$tag exit $($p.ExitCode)"
}
"started $(Get-Date -Format s)" | Set-Content $log -Encoding ascii
$src = "$bf\Inkling-2-Mini-BF16.gguf"; $im = "$bf\imatrix.gguf"
$experts = @('--tensor-type', '"blk\.(22|23)\.ffn_.*_exps=iq4_nl"', '--tensor-type', '"ffn_.*_exps=iq3_xxs"')
# name, base ftype, output head type
$variants = @(@('mixC-d5', 'Q5_K_M', 'q6_k'), @('mixC-d4', 'Q4_K_M', 'q6_k'), @('mixC-d4o5', 'Q4_K_M', 'q5_k'))
foreach ($v in $variants) {
  $out = "$models\Inkling-2-Mini-$($v[0]).gguf"
  if (Test-Path $out) { continue }
  $a = @('--pad-exps', '--imatrix', "`"$im`"", '--token-embedding-type', 'q8_0', '--output-tensor-type', $v[2]) + $experts + @("`"$src`"", "`"$out.tmp`"", $v[1], '24')
  Run $q $a "quant-$($v[0])"
  if (Test-Path "$out.tmp") { Rename-Item "$out.tmp" $out; L "$($v[0]) GiB $([math]::Round((Get-Item $out).Length/1GB,3))" }
}
if ($WaitFile) { while (-not (Test-Path $WaitFile)) { Start-Sleep 30 } }
L 'GPU steps start'
$pp = @('-f', "`"$bf\wiki.test.raw`"", '-c', '512', '-b', '512', '--chunks', '50', '-ngl', '99', '-fa', 'on', '-t', '16',
  '-ot', '"blk\.(22|23)\.ffn_.*_exps=CPU"', '--kl-divergence-base', "`"$bf\q8.kld`"", '--kl-divergence')
$ot = 'blk\.(20|21|22|23)\.ffn_.*_exps=CPU'
foreach ($name in @('mixC') + ($variants | ForEach-Object { $_[0] })) {
  $m = "$models\Inkling-2-Mini-$name.gguf"
  if (-not (Test-Path $m)) { L "$name missing"; continue }
  Run $ppl (@('-m', "`"$m`"") + $pp) "dense-kld-$name"
  Get-Content "$res\dense-kld-$name.out.log", "$res\dense-kld-$name.err.log" -ErrorAction SilentlyContinue |
    Select-String -Pattern 'Mean\s+KLD|Same top p|99\.0%\s+KLD' | ForEach-Object { L "$name | $($_.Line.Trim())" }
  $tag = "dense-speed-$name"
  Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$root\pecera\bench.ps1", '-Exe', $srv, '-Tag', $tag, '-Model', $m, '-Ctx', '65536', '-Ot', $ot -WindowStyle Hidden -Wait
  Get-Content "$res\$tag.txt" -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(up=|greedy run|chat run|gpu_after|pp)' } | ForEach-Object { L "$name | $_" }
}
'DONE' | Add-Content $log -Encoding ascii
