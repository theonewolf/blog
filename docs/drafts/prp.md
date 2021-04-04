# Pseudorandom Permutations in O(1)

What if you wanted to enumerate all 32-bit integers in a random order,
**without repetition**?  In other words, how would you create a random
permutation of the entire 32-bit space?

For just 32-bit integers, perhaps we could enumerate all of them---that would
just take $2^{32} * 32$ bits $= 16$ Gibibytes of RAM.  Possible on today's
laptops, and desktops.

But what about all 64-bit integers (you'd need $128$ Exbibytes)?  Not possible
even with the huge RAM of cloud servers!  And don't even think about it for
128-bit integers (you'd need $4.5 x 10^{15}$ Yobibytes).

What if I told you there is a method of doing this in
[O(1)](https://en.wikipedia.org/wiki/Big_O_notation#Orders_of_common_functions)
Space space?  Essentially, just size of two integers.  Worst case two 128-bit
(so, a total of 256 bits) integers.

First, I'll show of a quick and dirty way of doing this.  In followup articles,
I'll showcase more advanced methods.

## Try it out

TODO

## What is a [Pseudorandom Permutation (PRP)](https://en.wikipedia.org/wiki/Pseudorandom_permutation)?

Our requirement is to be able to enumerate all values without repetition, and
in random orders.  If we kept doing it, it should be possible to enumerate all
possible permutations as well.  This means we can't just use a simple counter.
We also can't use typical random number generators, as they allow repititions
to occur---which is also critical for their randomness properties.

What can we do?  It turns out there is something called a pseudorandom
permutation.  Remember, a permutation is an ordered values.  If, for example,
our domain was $[1,3]$, then a valid permutation would be:

\begin{equation} \{ 1, 2, 3 \} \end{equation}

Other, valid permutations include:

\begin{eqnarray} \{ 1, 3, 2 \} \\ \{ 2, 1, 3 \} \\ \{ 2, 3, 1 \} \\ \{ 3, 1, 2
\} \\ \{ 3, 2, 1 \} \end{eqnarray}

If you remember how to count permutations, we are picking 3 values out of 3
possible values, thus there are $P(3, 3) = (3)!(3-3)! = (3)!(0)! = (1*2*3)(1) =
6$ valid choices.

A PRP would just give us a permutation from the list above with uniform
probability.  In other words, all six permutations would appear from a PRP generator
with equal likelihood (1/6 of the time).

## [Bijective Functions](https://en.wikipedia.org/wiki/Bijection) and [Block Ciphers](https://en.wikipedia.org/wiki/Block_cipher)

It turns out that there are encryption schemes designed to do just this.  At
its most basic level, a block cipher is a bijective function mapping n-bit
values into other n-bit values.  Because it is bijective, if you just feed any
block cipher the previous result and key, it will produce the next value in
your pseudorandom permutation.

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
128\textsf{-bit}$

AES-256 is a 128-bit block cipher, meaning it maps all 128-bit strings into all
128-bit strings without repetition---otherwise we couldn't encrypt all possible
values.  If you were wondering why is it called AES-256 and not AES-128, the
256 in its abbreviated name refers to the key size---not the block size.

To generate a random permutation in the 128-bit space, we can just use AES-256
directly.  We will need a couple variables kept in memory, but once we have
these, we can continue generating a pseudorandom permutation in the 128-bit
space:



## [Format-preserving Encryption](https://en.wikipedia.org/wiki/Format-preserving_encryption) (FPE) and [NIST Standardization](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38G.pdf)

In a follow up article, I'll extend this idea to arbitrary bit-length strings,
and overview of new standardization efforts by NIST and the NSA to formalize
algorithms implementing FPE.

FPE is useful to mask things like credit card numbers, SSNs, zip codes, phone
numbers, really data where it is useful to retain the _shape_ of the data, but
not the precise value.  In fact, preserving the precise value may violate
compliance in scenarios such as HIPAA/HITRUST and PCI- or PA- DSS.


<script src="/js/wasm_exec.js"></script>
<script>
    const go = new Go();
    WebAssembly.instantiateStreaming(fetch("/wasm/main.wasm"), go.importObject).then((result) => {
        go.run(result.instance);
    });
</script>
