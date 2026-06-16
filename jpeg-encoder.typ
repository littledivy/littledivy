#import "./shim/html.typ": *

#set document(
  title: "The Mathematics of JPEG Compression",
  date: datetime(day: 19, month: 1, year: 2026),
  description: "A deep dive into the mathematical foundations of JPEG image encoding",
)

#show: html-shim

#show math.equation.where(block: false): it => {
  if target() == "html" {
    html.elem("span", attrs: (class: "math"), html.frame(it))
  } else {
    it
  }
}

#show math.equation.where(block: true): it => {
  if target() == "html" {
    html.elem("figure", attrs: (class: "math"), html.frame(it))
  } else {
    it
  }
}

// for styling, use `where` to assign classes for different types of figure
#show figure: it => {
  if target() == "html" { 
    html.elem("figure", attrs: (class: "typst"), html.frame(it))
  } else {
    it
  }
}

#nav-bar()

#title()
#byline()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

JPEG has been the dominant image format on the web for over three decades. Despite the emergence of modern formats like WebP and AVIF, JPEG remains ubiquitous due to its elegant mathematical foundation and remarkable compression efficiency.

Let's explore the mathematics that makes JPEG work, from color space transformations to discrete cosine transforms.

= Color Space Transformation

The first step in JPEG encoding is transforming the image from RGB to YCbCr color space. This exploits the human visual system's greater sensitivity to brightness (luminance) than color (chrominance)#sidenote[This is why chroma can be subsampled but luma cannot — the eye notices luma detail far more.].

The transformation is defined as:

#M(`\begin{aligned} Y &= 0.299R + 0.587G + 0.114B \\ C_b &= -0.168736R - 0.331264G + 0.5B + 128 \\ C_r &= 0.5R - 0.418688G - 0.081312B + 128 \end{aligned}`)

Or in matrix form:

#M(`\begin{pmatrix} Y \\ C_b \\ C_r \end{pmatrix} = \begin{pmatrix} 0.299 & 0.587 & 0.114 \\ -0.168736 & -0.331264 & 0.5 \\ 0.5 & -0.418688 & -0.081312 \end{pmatrix} \begin{pmatrix} R \\ G \\ B \end{pmatrix} + \begin{pmatrix} 0 \\ 128 \\ 128 \end{pmatrix}`)

The inverse transformation for decoding:

#M(`\begin{aligned} R &= Y + 1.402(C_r - 128) \\ G &= Y - 0.344136(C_b - 128) - 0.714136(C_r - 128) \\ B &= Y + 1.772(C_b - 128) \end{aligned}`)

After this transformation, we can downsample the chroma channels (Cb and Cr) by a factor of 2 in each dimension (4:2:0 subsampling) with minimal perceptual quality loss. This immediately gives us a 2x compression ratio.

#note[4:2:0 stores one Cb and one Cr sample per 2x2 luma block, discarding three quarters of the chroma resolution before any DCT runs. The savings are nearly free perceptually, which is why it is the default for most JPEG pipelines.]

In code, this transformation looks like:

```rust
let r = src_data[src_index] as f32;
let g = src_data[src_index + 1] as f32;
let b = src_data[src_index + 2] as f32;

let luma = 0.299 * r + 0.587 * g + 0.114 * b - 128.0;
let cb = -0.1687 * r - 0.3313 * g + 0.5 * b;
let cr = 0.5 * r - 0.4187 * g - 0.0813 * b;
```

Note the `-128.0` offset on the luma channel—this centers the values around zero before the DCT, which improves compression efficiency.

= The Discrete Cosine Transform

The heart of JPEG is the Discrete Cosine Transform (DCT). The image is divided into 8x8 blocks, and each block is transformed from the spatial domain to the frequency domain.

For an 8x8 block of pixels #m(`f(x, y)`) where #m(`x, y \in [0, 7]`), the 2D DCT is defined as:

#M(`F(u, v) = \frac{1}{4} C(u)C(v) \sum_{x=0}^{7} \sum_{y=0}^{7} f(x, y) \cos\frac{(2x + 1)u\pi}{16} \cos\frac{(2y + 1)v\pi}{16}`)

where the normalization coefficients are:

#M(`C(u) = \begin{cases} \frac{1}{\sqrt{2}} & \text{if } u = 0 \\ 1 & \text{otherwise} \end{cases}`)

The DCT transforms spatial pixel values into frequency coefficients. The coefficient #m(`F(0, 0)`) is the DC component (average value), while higher indices represent higher frequency components.

The beauty of the DCT is that it's a real-valued transform (unlike the complex-valued Fourier transform)#sidenote[The DCT uses a real cosine basis, avoiding complex arithmetic and the boundary discontinuities that cause Gibbs ringing in the DFT.] and has excellent energy compaction properties for natural images. Most of the signal energy concentrates in the low-frequency coefficients (top-left of the transformed block).

The inverse DCT reconstructs the spatial domain:

#M(`f(x, y) = \frac{1}{4} \sum_{u=0}^{7} \sum_{v=0}^{7} C(u)C(v)F(u, v) \cos\frac{(2x + 1)u\pi}{16} \cos\frac{(2y + 1)v\pi}{16}`)

= Why the DCT Works

The DCT's effectiveness stems from the Karhunen-Loève theorem. For a first-order Markov process with correlation coefficient #m(`\rho`), the DCT approaches the optimal Karhunen-Loève Transform (KLT) as #m(`\rho \to 1`).

Natural images exhibit high spatial correlation (neighboring pixels are similar), making the DCT nearly optimal for decorrelation. This concentrates energy into fewer coefficients, enabling efficient compression.

The basis functions of the 8x8 DCT can be visualized as 64 patterns. For position #m(`(u, v)`), the basis function is:

#M(`B_{u,v}(x, y) = C(u)C(v) \cos\frac{(2x + 1)u\pi}{16} \cos\frac{(2y + 1)v\pi}{16}`)

Any 8x8 block can be represented as a weighted sum of these basis functions, where the weights are the DCT coefficients.

= Quantization: Where Compression Happens

After the DCT, we have 64 floating-point coefficients per block. Quantization is where lossy compression occurs by dividing each coefficient by a quantization value and rounding:

#M(`F_Q(u, v) = \text{round}\left(\frac{F(u, v)}{Q(u, v)}\right)`)

The quantization matrix #m(`Q(u, v)`) is carefully designed to preserve perceptually important low-frequency components while aggressively quantizing high-frequency components.

A typical luminance quantization matrix (at quality 50):

#M(`Q = \begin{pmatrix} 16 & 11 & 10 & 16 & 24 & 40 & 51 & 61 \\ 12 & 12 & 14 & 19 & 26 & 58 & 60 & 55 \\ 14 & 13 & 16 & 24 & 40 & 57 & 69 & 56 \\ 14 & 17 & 22 & 29 & 51 & 87 & 80 & 62 \\ 18 & 22 & 37 & 56 & 68 & 109 & 103 & 77 \\ 24 & 35 & 55 & 64 & 81 & 104 & 113 & 92 \\ 49 & 64 & 78 & 87 & 103 & 121 & 120 & 101 \\ 72 & 92 & 95 & 98 & 112 & 100 & 103 & 99 \end{pmatrix}`)

Notice how values increase toward the bottom-right (high frequencies), causing more aggressive quantization where the human eye is less sensitive.

This matrix is defined in the JPEG specification and stored as a constant:

```rust
const DEFAULT_QT_LUMA_FROM_SPEC: [u8; 64] = [
    16, 11, 10, 16, 24, 40, 51, 61,
    12, 12, 14, 19, 26, 58, 60, 55,
    14, 13, 16, 24, 40, 57, 69, 56,
    14, 17, 22, 29, 51, 87, 80, 62,
    18, 22, 37, 56, 68, 109, 103, 77,
    24, 35, 55, 64, 81, 104, 113, 92,
    49, 64, 78, 87, 103, 121, 120, 101,
    72, 92, 95, 98, 112, 100, 103, 99,
];
```

The quality parameter scales this matrix:

#M(`Q'(u, v) = \begin{cases} \lfloor (\frac{50}{q})Q(u, v) + 0.5 \rfloor & \text{if } q < 50 \\ \lfloor (2 - \frac{q}{50})Q(u, v) \rfloor & \text{if } q \geq 50 \end{cases}`)

where #m(`q`) is the quality setting (1-100). A simplified implementation might use discrete quality levels:

```rust
match quality {
    3 => {
        // Maximum quality: no quantization
        qt_luma = [1; 64];
        qt_chroma = [1; 64];
    }
    2 | 1 => {
        let qt_factor = if quality == 2 { 10 } else { 1 };
        for i in 0..64 {
            qt_luma[i] = (DEFAULT_QT_LUMA_FROM_SPEC[i] / qt_factor).max(1);
            qt_chroma[i] = (DEFAULT_QT_CHROMA_FROM_PAPER[i] / qt_factor).max(1);
        }
    }
}
```

This quantization step is irreversible.#sidenote[The rounding discards information permanently; everything else in the pipeline is exactly invertible, so this is the sole source of loss.] Most JPEG artifacts (blocking, ringing) originate here.

The quantization is implemented as:

```rust
for i in 0..64 {
    let mut fval = dct_mcu[i] * qt[i];
    fval = (fval + 1024.0 + 0.5).floor() - 1024.0;
    du[ZIG_ZAG[i] as usize] = fval as i32;
}
```

The `qt[i]` values are precomputed as `1.0 / (8.0 * AAN_SCALES[x] * AAN_SCALES[y] * Q[i])` to combine quantization with DCT scaling in a single multiplication.

= Entropy Encoding

After quantization, we have a sparse matrix of integers. The coefficients are then zigzag scanned:

```
Start -> 0  1  5  6  ...
         2  4  7  ...
         3  8  ...
         9  ...
        ...
```

This ordering groups low-frequency coefficients first and creates long runs of zeros for high-frequency components.

The zigzag pattern is hardcoded as a lookup table:

```rust
const ZIG_ZAG: [u8; 64] = [
    0, 1, 5, 6, 14, 15, 27, 28,
    2, 4, 7, 13, 16, 26, 29, 42,
    3, 8, 12, 17, 25, 30, 41, 43,
    9, 11, 18, 24, 31, 40, 44, 53,
    10, 19, 23, 32, 39, 45, 52, 54,
    20, 22, 33, 38, 46, 51, 55, 60,
    21, 34, 37, 47, 50, 56, 59, 61,
    35, 36, 48, 49, 57, 58, 62, 63,
];
```

The DC coefficient (top-left) is encoded differentially from the previous block's DC value, since DC values are highly correlated across blocks:

#M(`\text{DIFF} = \text{DC}_{\text{current}} - \text{DC}_{\text{previous}}`)

AC coefficients are run-length encoded (RLE) as (run, value) pairs where run is the number of consecutive zeros.

The AC encoding algorithm:

```rust
let mut i = 1;
while i <= last_non_zero_i {
    let mut zero_count = 0;
    while du[i] == 0 {
        zero_count += 1;
        i += 1;
        if zero_count == 16 {
            // Emit ZRL symbol (0xF0) for 16 consecutive zeros
            write_bits(bitbuffer, location,
                      huff_ac_len[0xf0], huff_ac_code[0xf0])?;
            zero_count = 0;
        }
    }

    let (bits, num_bits) = calculate_variable_length_int(du[i]);
    let sym = ((zero_count << 4) | num_bits) as usize;

    write_bits(bitbuffer, location, huff_ac_len[sym], huff_ac_code[sym])?;
    write_bits(bitbuffer, location, num_bits, bits)?;
    i += 1;
}
```

The symbol combines the zero run-length (upper 4 bits) and coefficient bit length (lower 4 bits) into a single byte, which is then Huffman coded.

Finally, Huffman coding assigns variable-length codes based on symbol frequency. Common symbols get shorter codes, rare symbols get longer codes, achieving the theoretical entropy limit:

#M(`H = -\sum_{i=1}^{n} p_i \log_2 p_i`)

where #m(`p_i`) is the probability of symbol #m(`i`).

= The Complete Pipeline

Putting it all together, JPEG encoding follows these steps:

1. RGB → YCbCr color space conversion
2. Chroma subsampling (typically 4:2:0)
3. Divide into 8×8 blocks
4. Level shift by -128 (center around zero)
5. Apply 2D DCT to each block
6. Quantize coefficients using quality-dependent matrix
7. Zigzag scan to create 1D sequence
8. DC differential encoding
9. AC run-length encoding
10. Huffman entropy coding

Each step is mathematically reversible except quantization, making JPEG a lossy format with controlled degradation.

The encoder processes the image in 8×8 blocks:

```rust
for y in (0..height).step_by(8) {
    for x in (0..width).step_by(8) {
        let mut du_y = [0.0f32; 64];
        let mut du_b = [0.0f32; 64];
        let mut du_r = [0.0f32; 64];

        // Extract 8x8 block and convert RGB -> YCbCr
        for off_y in 0..8 {
            for off_x in 0..8 {
                let (r, g, b) = get_pixel(x + off_x, y + off_y);
                du_y[off_y * 8 + off_x] = 0.299*r + 0.587*g + 0.114*b - 128.0;
                du_b[off_y * 8 + off_x] = -0.1687*r - 0.3313*g + 0.5*b;
                du_r[off_y * 8 + off_x] = 0.5*r - 0.4187*g - 0.0813*b;
            }
        }

        // DCT + Quantize + Huffman encode each channel
        encode_and_write_mcu(state, &du_y, &qt_luma, ...);
        encode_and_write_mcu(state, &du_b, &qt_chroma, ...);
        encode_and_write_mcu(state, &du_r, &qt_chroma, ...);
    }
}
```

= Fast DCT Implementation

The naive DCT implementation has #m(`O(N^{4})`) complexity for an #m(`N \times N`) block (requires 4096 multiplications for 8×8). Practical encoders use separable 1D DCTs and fast algorithms like Arai, Agui, and Nakajima (AAN).

The 2D DCT can be separated into two 1D transforms:

#M(`F(u, v) = \text{DCT}_y (\text{DCT}_x (f(x, y)))`)

The AAN algorithm reduces 8-point DCT to just 29 multiplications and 5 additions by exploiting symmetry:

#M(`\text{DCT}(x) = C \cdot A \cdot x`)

where #m(`A`) is a sparse butterfly matrix and #m(`C`) contains scaling factors.

Here's how the AAN algorithm processes one row of an 8×8 block:

```rust
// Stage 1: Even/odd butterflies
let tmp0 = data[i] + data[i + 7];
let tmp7 = data[i] - data[i + 7];
let tmp1 = data[i + 1] + data[i + 6];
let tmp6 = data[i + 1] - data[i + 6];
let tmp2 = data[i + 2] + data[i + 5];
let tmp5 = data[i + 2] - data[i + 5];
let tmp3 = data[i + 3] + data[i + 4];
let tmp4 = data[i + 3] - data[i + 4];

// Stage 2: Even part
let tmp10 = tmp0 + tmp3;
let tmp13 = tmp0 - tmp3;
let tmp11 = tmp1 + tmp2;
let tmp12 = tmp1 - tmp2;

data[i] = tmp10 + tmp11;
data[i + 4] = tmp10 - tmp11;

let z1 = (tmp12 + tmp13) * 0.707106781; // sqrt(2)/2
data[i + 2] = tmp13 + z1;
data[i + 6] = tmp13 - z1;

// Stage 3: Odd part (simplified)
let z5 = (tmp10 - tmp12) * 0.382683433;
let z2 = 0.541196100 * tmp10 + z5;
let z4 = 1.306562965 * tmp12 + z5;
// ... continues with z3, z11, z13
```

The magic constants (0.707106781, 0.382683433, etc.) are precomputed trigonometric values that exploit the symmetry of cosine functions. Modern SIMD implementations can transform an 8×8 block in under 100 CPU cycles.

= Optimizations and Variations

Progressive JPEG encodes images in multiple scans, first sending low-frequency coefficients for a rough preview, then refining with higher frequencies. This is achieved by spectral selection (frequency ranges) and successive approximation (bit planes).

Arithmetic coding can replace Huffman coding for 5-10% better compression at the cost of computational complexity and patent concerns (now expired).

Optimized Huffman tables computed specifically for each image can improve compression by 2-8% over default tables.

= Why JPEG Remains Relevant

Despite being designed in 1992, JPEG's mathematical foundation is remarkably sound. The DCT transform, perceptual quantization, and entropy coding form a nearly optimal pipeline for lossy image compression within its computational constraints.

Modern formats like JPEG XL build on these principles with more sophisticated transforms (overlapped, variable-size blocks) and better entropy coding, but the core ideas remain the same.

For a deeper dive, the official specification is ITU-T T.81 (ISO/IEC 10918-1).

The math behind JPEG is a beautiful example of how signal processing theory, linear algebra, and information theory combine to solve a real-world problem that billions of people rely on every day.
