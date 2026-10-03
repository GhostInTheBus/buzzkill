#!/bin/zsh
# Every suite against every data extract. Exit non-zero on any failure.
cd "$(dirname "$0")/.."
./build.sh >/dev/null || exit 1
fail=0
for d in data data-malecns; do
  [ -f "$d/circuit.json" ] || continue
  echo "== $d"
  for t in simtest behaviortest locomotortest populationtest; do
    out=$(BUZZKILL_DATA=$d ./Buzzkill --$t 2>&1)
    line=$(echo "$out" | grep -E '^PASS: GF|ALL .* PASS|FAILURES|^FAIL: ' | tail -1)
    echo "   $t: $line"
    echo "$line" | grep -q -E 'PASS' || { fail=1; echo "$out" | grep -E '^FAIL' | sed 's/^/      /'; }
  done
  echo "   gfstat: $(BUZZKILL_DATA=$d ./Buzzkill --gfstat)"
done
exit $fail
