# Pseudorandom Permutations in O(1)

What if you wanted to enumerate all 32-bit integers in a random order,
**without repetition**?  In other words, how would you create a random
permutation of the entire 32-bit space?

For just 32-bit integers, perhaps we could enumerate all of them---that would
just take $2^{32} \times 32$ bits $= 16$ Gibibytes of RAM.  Possible on today's
laptops and desktops.

But what about all 64-bit integers (you'd need $128$ Exbibytes)?  Not possible
even with the huge RAM of cloud servers!  And don't even think about it for
128-bit integers (you'd need $4.5 \times 10^{15}$ Yobibytes).

What if I told you there is a method of doing this in
[O(1)](https://en.wikipedia.org/wiki/Big_O_notation#Orders_of_common_functions)
space?  Essentially, just the size of two integers.  Worst case two 128-bit
(so, a total of 256 bits) integers.

First, I'll show off a quick and dirty way of doing this.  In follow-up articles,
I'll showcase more advanced methods.

## Try it out

Below is a live **Feistel Finite Set Encryption Mode (FFSEM)** demo compiled
from Zig to a 12 KB standalone WebAssembly module running locally in your
browser.  Pick one of the worked-out examples or enter any arbitrary input,
domain size $M \in [2, 2^{128})$, round count, and key to inspect every
Feistel round and cycle-walking pass.

<div id="ffsem-demo" class="ffsem-demo">
  <div class="ffsem-presets">
    <span class="ffsem-presets-label">Examples:</span>
    <button type="button" class="ffsem-preset-btn" data-preset="small">10-bit ([0, 1023), x = 42)</button>
    <button type="button" class="ffsem-preset-btn" data-preset="cycle">Cycle Walking ([0, 1000), x = 4)</button>
    <button type="button" class="ffsem-preset-btn" data-preset="fpe16">16-digit FPE ([0, 10^16))</button>
    <button type="button" class="ffsem-preset-btn" data-preset="u128">128-bit ([0, 10^27))</button>
  </div>
  <p id="ffsem-note" class="ffsem-note" hidden></p>
  <div class="ffsem-grid">
    <div class="ffsem-field">
      <label for="ffsem-x">Input (x)</label>
      <input id="ffsem-x" type="text" value="42" autocomplete="off" spellcheck="false">
    </div>
    <div class="ffsem-field">
      <label for="ffsem-max">Domain max (M, range [0, M))</label>
      <input id="ffsem-max" type="text" value="1023" autocomplete="off" spellcheck="false">
    </div>
    <div class="ffsem-field">
      <label for="ffsem-rounds">Rounds (1&ndash;32)</label>
      <input id="ffsem-rounds" type="number" min="1" max="32" value="6">
    </div>
    <div class="ffsem-field">
      <label for="ffsem-key">AES-256 Key (up to 32 bytes)</label>
      <input id="ffsem-key" type="text" value="theonewolf-prp-demo-key" autocomplete="off" spellcheck="false">
    </div>
  </div>
  <div class="ffsem-actions">
    <button type="button" id="ffsem-encrypt" class="md-button md-button--primary">Encrypt</button>
    <button type="button" id="ffsem-decrypt" class="md-button">Decrypt</button>
    <button type="button" id="ffsem-flip" class="md-button" disabled>Decrypt Result</button>
  </div>
  <div id="ffsem-error" class="ffsem-error" hidden></div>
  <div id="ffsem-summary" class="ffsem-summary" hidden></div>
  <div id="ffsem-trace"></div>
</div>

### Worked-out Examples to Notice

1. **10-bit Balanced Feistel (`[0, 1023)`, `x = 42`)**: With $M = 1023$, FFSEM
   uses a 10-bit Feistel block split into two 5-bit halves $(L, R)$.  Over 6
   rounds of AES-256, `42` maps to `999` in a single pass.  Click **Decrypt
   Result** to watch the exact same 6 rounds run in reverse (`5 → 0`) and
   recover `42`.
2. **Cycle Walking (`[0, 1000)`, `x = 4`)**: The smallest even bit-width
   covering `[0, 1000)` is still 10 bits (`[0, 1024)`).  On Pass 1, encrypting
   `4` lands in the out-of-range tail `[1000, 1023]`, so FFSEM feeds that
   intermediate output right back into the Feistel network until it lands below
   `1000` (`530`).  Because every pass is a bijection, decrypting `530` walks
   back through the exact same out-of-range value to `4`.
3. **16-Digit FPE (`[0, 10^16)`) & 128-Bit Space (`[0, 10^27)`)**: Demonstrates
   preserving a 16-digit card-number shape (54-bit Feistel) and operating
   natively above 64 bits (90-bit Feistel) using Zig's built-in `u128`.

## What is a [Pseudorandom Permutation (PRP)](https://en.wikipedia.org/wiki/Pseudorandom_permutation)?

Our requirement is to be able to enumerate all values without repetition, and
in random orders.  If we kept doing it, it should be possible to enumerate all
possible permutations as well.  This means we can't just use a simple counter.
We also can't use typical random number generators, as they allow repetitions
to occur---which is also critical for their randomness properties.

What can we do?  It turns out there is something called a pseudorandom
permutation.  Remember, a permutation is an ordering of values.  If, for
example, our domain was $[1,3]$, then a valid permutation would be:

\begin{equation} (1, 2, 3) \end{equation}

Other valid permutations include:

\begin{eqnarray} (1, 3, 2) \\ (2, 1, 3) \\ (2, 3, 1) \\ (3, 1, 2)
\\ (3, 2, 1) \end{eqnarray}

If you remember how to count permutations, we are picking 3 values out of 3
possible values, thus there are $P(3, 3) = \frac{3!}{(3-3)!} = \frac{3!}{0!} =
\frac{1 \times 2 \times 3}{1} = 6$ valid choices.

A PRP would just give us a permutation from the list above with uniform
probability.  In other words, all six permutations would appear from a PRP generator
with equal likelihood (1/6 of the time).

## [Bijective Functions](https://en.wikipedia.org/wiki/Bijection) and [Block Ciphers](https://en.wikipedia.org/wiki/Block_cipher)

It turns out that there are encryption schemes designed to do just this.  At
its most basic level, a block cipher is a bijective function mapping $n$-bit
values into other $n$-bit values.  Because it is bijective, if you feed a
counter ($0, 1, 2, \dots$) and a key into a block cipher, each distinct counter
value produces a distinct output---enumerating the entire space in pseudorandom
order without repetition.  The counter is necessary because feeding each output
back into the cipher only walks one of its disjoint cycles and can repeat
early (for AES specifically, every encryption is an even permutation in
$A_{2^{128}}$, so a single full-length cycle is mathematically impossible).

To refresh ourselves, the definition of a bijective function $f\colon X \to Y$
is:

1. each element of $X$ must be paired with at least one element of $Y$,
2. no element of $X$ may be paired with more than one element of $Y$,
3. each element of $Y$ must be paired with at least one element of $X$, and
4. no element of $Y$ may be paired with more than one element of $X$.

In other words, every input maps to one and only one output, and the number of
elements in the input equals the number of elements in the output.

Such a mapping is a valid permutation!  It just so happens that in the 128-bit
space, a cipher like
[AES-256](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard) is a
bijective function defined as: $\textsf{AES-}256\colon 128\textsf{-bit} \to
128\textsf{-bit}$.

AES-256 is a 128-bit block cipher, meaning it maps all 128-bit strings into all
128-bit strings without repetition---otherwise we couldn't encrypt all possible
values.  If you were wondering why it is called AES-256 and not AES-128, the
256 in its abbreviated name refers to the key size---not the block size.

To generate a random permutation over an arbitrary range $[0, M)$ up to the
128-bit space, we can wrap AES-256 in a balanced Feistel network with cycle
walking (FFSEM).

!!! note "Implementation Note"
    I originally wrote this implementation in Golang, but redid it with Gemini
    4 Neon in **Zig** because Zig has native 128-bit integer support (`u128`)
    and is a simple systems programming language with an easier learning curve
    compared to Rust.  It also compiles directly to a tiny 12 KB standalone
    WebAssembly module with no runtime overhead.  The source code below is
    released under the **MIT License**.

```zig
--8<-- "src/zig-ffsem/ffsem.zig"
```

## [Format-preserving Encryption](https://en.wikipedia.org/wiki/Format-preserving_encryption) (FPE) and [NIST Standardization](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38G.pdf)

In a follow-up article, I'll extend this idea to arbitrary bit-length strings,
and give an overview of new standardization efforts by NIST and the NSA to
formalize algorithms implementing FPE.

FPE is useful to mask things like credit card numbers, SSNs, zip codes, phone
numbers, really data where it is useful to retain the _shape_ of the data, but
not the precise value.  In fact, preserving the precise value may violate
compliance in scenarios such as HIPAA/HITRUST and PCI-DSS or PA-DSS.
