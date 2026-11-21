(() => {
  const MASK64 = (1n << 64n) - 1n;
  const MAX_U128 = (1n << 128n) - 1n;
  const STEP_STRIDE = 10;

  const PRESETS = {
    small: {
      x: "42",
      max: "1023",
      rounds: "6",
      key: "theonewolf-prp-demo-key",
      note: "10-bit balanced Feistel (two 5-bit halves) over [0, 1023). Click \"Decrypt Result\" to watch all 6 rounds unwind back to 42."
    },
    cycle: {
      x: "4",
      max: "1000",
      rounds: "6",
      key: "theonewolf-prp-demo-key",
      note: "Cycle walking in action: Pass 1 lands in [1000, 1023] (outside [0, 1000)), so FFSEM automatically feeds it through a second Feistel pass until the result is < 1000."
    },
    fpe16: {
      x: "4111111111111111",
      max: "10000000000000000",
      rounds: "6",
      key: "theonewolf-prp-demo-key",
      note: "Format-preserving encryption over 16-digit numbers [0, 10^16) using a 54-bit Feistel network (two 27-bit halves) — preserves the 16-digit shape."
    },
    u128: {
      x: "123456789012345678901234567",
      max: "1000000000000000000000000000",
      rounds: "6",
      key: "theonewolf-prp-demo-key",
      note: "Native 128-bit arithmetic: a 90-bit Feistel network (two 45-bit halves) over [0, 10^27) running directly in Zig u128 WebAssembly."
    }
  };

  let wasmPromise = null;

  function loadWasm() {
    if (!wasmPromise) {
      const wasmUrl = new URL("/wasm/ffsem.wasm", window.location.origin);
      wasmPromise = fetch(wasmUrl)
        .then((res) => {
          if (!res.ok) throw new Error(`Failed to load ${wasmUrl} (${res.status})`);
          return res.arrayBuffer();
        })
        .then((bytes) => WebAssembly.instantiate(bytes))
        .then(({ instance }) => instance.exports);
    }
    return wasmPromise;
  }

  function parseBigIntField(raw, label) {
    const cleaned = raw.trim().replace(/[_, \s]/g, "");
    if (!/^\d+$/.test(cleaned)) {
      throw new Error(`${label} must be a non-negative integer.`);
    }
    const val = BigInt(cleaned);
    if (val > MAX_U128) {
      throw new Error(`${label} must fit in an unsigned 128-bit integer (< 2^128).`);
    }
    return val;
  }

  function formatVal(v, halfBits) {
    const hexDigits = Math.max(2, Math.ceil(halfBits / 4));
    const hex = "0x" + v.toString(16).padStart(hexDigits, "0");
    return `${v.toString(10)} <span class="ffsem-hex">(${hex})</span>`;
  }

  function initDemo() {
    const root = document.getElementById("ffsem-demo");
    if (!root || root.dataset.initialized === "true") return;
    root.dataset.initialized = "true";

    const xInput = root.querySelector("#ffsem-x");
    const maxInput = root.querySelector("#ffsem-max");
    const roundsInput = root.querySelector("#ffsem-rounds");
    const keyInput = root.querySelector("#ffsem-key");
    const noteEl = root.querySelector("#ffsem-note");
    const errorEl = root.querySelector("#ffsem-error");
    const summaryEl = root.querySelector("#ffsem-summary");
    const traceEl = root.querySelector("#ffsem-trace");
    const encBtn = root.querySelector("#ffsem-encrypt");
    const decBtn = root.querySelector("#ffsem-decrypt");
    const flipBtn = root.querySelector("#ffsem-flip");

    let lastResult = null;
    let lastMode = "encrypt";

    async function execute(mode) {
      errorEl.hidden = true;
      errorEl.textContent = "";

      let x, max, rounds;
      try {
        x = parseBigIntField(xInput.value, "Input (x)");
        max = parseBigIntField(maxInput.value, "Domain max (M)");
        rounds = Number.parseInt(roundsInput.value.trim(), 10);
        if (!Number.isInteger(rounds) || rounds < 1 || rounds > 32) {
          throw new Error("Rounds must be an integer between 1 and 32.");
        }
        if (max < 2n) {
          throw new Error("Domain max (M) must be at least 2.");
        }
        if (x >= max) {
          throw new Error(`Input x (${x}) must be strictly less than Domain max M (${max}).`);
        }
      } catch (err) {
        errorEl.textContent = err.message;
        errorEl.hidden = false;
        return;
      }

      try {
        const exports = await loadWasm();
        const { memory, keyPtr, ioPtr, tracePtr, runEncrypt, runDecrypt } = exports;

        const keyView = new Uint8Array(memory.buffer, keyPtr(), 32);
        keyView.fill(0);
        const keyBytes = new TextEncoder().encode(keyInput.value);
        keyView.set(keyBytes.slice(0, 32));

        const io = new BigUint64Array(memory.buffer, ioPtr(), 10);
        io[0] = x & MASK64;
        io[1] = x >> 64n;
        io[2] = max & MASK64;
        io[3] = max >> 64n;

        const rc = mode === "encrypt" ? runEncrypt(rounds) : runDecrypt(rounds);
        if (rc !== 0) {
          throw new Error(`WASM returned error code ${rc}.`);
        }

        const out = (io[5] << 64n) | io[4];
        const width = Number(io[6]);
        const half = Number(io[7]);
        const numSteps = Number(io[8]);
        const numWalks = Number(io[9]);

        lastResult = out;
        lastMode = mode;
        flipBtn.disabled = false;
        flipBtn.textContent = mode === "encrypt" ? "Decrypt Result" : "Encrypt Result";

        const opLabel = mode === "encrypt" ? "Encrypt" : "Decrypt";
        summaryEl.innerHTML = `
          <div class="ffsem-result-row">
            <span class="ffsem-badge">${opLabel}</span>
            <code>${x.toString(10)}</code>
            <span aria-hidden="true">&rarr;</span>
            <code class="ffsem-output">${out.toString(10)}</code>
          </div>
          <div class="ffsem-meta">
            <span><strong>Domain:</strong> [0, ${max.toString(10)})</span>
            <span><strong>Feistel block:</strong> ${width} bits (2 &times; ${half}-bit halves)</span>
            <span><strong>Rounds/pass:</strong> ${rounds}</span>
            <span><strong>Cycle-walk passes:</strong> ${numWalks}</span>
          </div>
        `;
        summaryEl.hidden = false;

        const traceView = new BigUint64Array(memory.buffer, tracePtr(), numSteps * STEP_STRIDE);
        const passes = new Map();
        for (let i = 0; i < numSteps; i++) {
          const b = i * STEP_STRIDE;
          const walk = Number(traceView[b]);
          const round = Number(traceView[b + 1]);
          const left = (traceView[b + 3] << 64n) | traceView[b + 2];
          const right = (traceView[b + 5] << 64n) | traceView[b + 4];
          const f = (traceView[b + 7] << 64n) | traceView[b + 6];
          const state = (traceView[b + 9] << 64n) | traceView[b + 8];
          if (!passes.has(walk)) passes.set(walk, []);
          passes.get(walk).push({ round, left, right, f, state });
        }

        const prfCol = mode === "encrypt" ? "F(R, r)" : "F(L, r)";
        let html = "";
        for (const [walkIdx, steps] of passes.entries()) {
          const passOut = steps[steps.length - 1].state;
          const accepted = passOut < max;
          const statusClass = accepted ? "ffsem-pass-ok" : "ffsem-pass-retry";
          const statusText = accepted
            ? `Pass ${walkIdx + 1} output ${passOut.toString(10)} &lt; ${max.toString(10)} — accepted`
            : `Pass ${walkIdx + 1} output ${passOut.toString(10)} &ge; ${max.toString(10)} — out of range, cycle walking again`;

          html += `
            <div class="ffsem-pass">
              <div class="ffsem-pass-header ${statusClass}">${statusText}</div>
              <div class="ffsem-table-wrap">
                <table class="ffsem-table">
                  <thead>
                    <tr>
                      <th>Round</th>
                      <th>Left (L)</th>
                      <th>Right (R)</th>
                      <th>${prfCol}</th>
                      <th>Combined State (L' || R')</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${steps
                      .map(
                        (s) => `
                      <tr>
                        <td><code>${s.round}</code></td>
                        <td><code>${formatVal(s.left, half)}</code></td>
                        <td><code>${formatVal(s.right, half)}</code></td>
                        <td><code>${formatVal(s.f, half)}</code></td>
                        <td><code>${formatVal(s.state, width)}</code></td>
                      </tr>`
                      )
                      .join("")}
                  </tbody>
                </table>
              </div>
            </div>
          `;
        }
        traceEl.innerHTML = html;
      } catch (err) {
        errorEl.textContent = err.message;
        errorEl.hidden = false;
      }
    }

    root.querySelectorAll("[data-preset]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const preset = PRESETS[btn.dataset.preset];
        if (!preset) return;
        xInput.value = preset.x;
        maxInput.value = preset.max;
        roundsInput.value = preset.rounds;
        keyInput.value = preset.key;
        noteEl.textContent = preset.note;
        noteEl.hidden = false;
        execute("encrypt");
      });
    });

    encBtn.addEventListener("click", () => execute("encrypt"));
    decBtn.addEventListener("click", () => execute("decrypt"));
    flipBtn.addEventListener("click", () => {
      if (lastResult === null) return;
      xInput.value = lastResult.toString(10);
      execute(lastMode === "encrypt" ? "decrypt" : "encrypt");
    });

    // Run default worked example on load
    const initial = PRESETS.small;
    noteEl.textContent = initial.note;
    noteEl.hidden = false;
    execute("encrypt");
  }

  if (typeof document$ !== "undefined") {
    document$.subscribe(() => initDemo());
  } else {
    document.addEventListener("DOMContentLoaded", initDemo);
  }
})();
