// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}




#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  place(
    top,
    float: true,
    scope: "parent",
    clearance: 4mm,
    block(below: 1em, width: 100%)[

      #if title != none {
        align(center, block(inset: 2em)[
          #set par(leading: heading-line-height) if heading-line-height != none
          #set text(font: heading-family) if heading-family != none
          #set text(weight: heading-weight)
          #set text(style: heading-style) if heading-style != "normal"
          #set text(fill: heading-color) if heading-color != black

          #text(size: title-size)[#title #if thanks != none {
            footnote(thanks, numbering: "*")
            counter(footnote).update(n => n - 1)
          }]
          #(if subtitle != none {
            parbreak()
            text(size: subtitle-size)[#subtitle]
          })
        ])
      }

      #if authors != none and authors != () {
        let count = authors.len()
        let ncols = calc.min(count, 3)
        grid(
          columns: (1fr,) * ncols,
          row-gutter: 1.5em,
          ..authors.map(author =>
              align(center)[
                #author.name \
                #author.affiliation \
                #author.email
              ]
          )
        )
      }

      #if date != none {
        align(center)[#block(inset: 1em)[
          #date
        ]]
      }

      #if abstract != none {
        block(inset: 2em)[
        #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
        ]
      }
    ]
  )

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  title: [Problem Set 4: Probabilitas dan Statistik],
  subtitle: [Lembar Soal dan Kunci Jawaban Lengkap],
  authors: (
    ( name: [Dosen: Dimitri Mahayana],
      affiliation: [],
      email: [] ),
    ),
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

== #strong[Soal 1]
<soal-1>
Misalkan $X$ adalah #emph[random variable] berdistribusi seragam dengan rentang bilangan bulat 0 sampai 9. Tentukan mean, variansi dan standar deviasi dari #emph[random variable] $Y = 5 X$ dan bandingkan hasilnya dengan $X$!

#strong[Jawaban:] Karena $X$ adalah #emph[random variable] berdistribusi seragam, maka mean dan variansinya dapat ditentukan sebagai berikut: $ E \( X \) = frac(9 + 0, 2) = 4 \, 5 $ $ sigma_X^2 = frac(\( 9 - 0 + 1 \)^2 - 1, 12) = 8 \, 25 $ $ sigma_X = sqrt(8 \, 25) = 2 \, 87 $ Karena $Y$ adalah fungsi dari $X$, maka mean dan variansinya dapat ditentukan sebagai berikut: $ E \( Y \) = E \( 5 X \) = 5 E \( X \) = 22 \, 5 $ $ sigma_Y^2 = \( 5 \)^2 sigma_X^2 = 25 times 8 \, 25 = 206 \, 25 $ $ sigma_Y = sqrt(206 \, 25) = 14 \, 36 $

#horizontalrule

== #strong[Soal 2]
<soal-2>
Jumlah panggilan telepon yang datang pada suatu operator selular sering dimodelkan sebagai #emph[random variable] yang mengikuti distribusi Poisson. Misalkan pada rata-ratanya, terdapat 10 panggilan per jam ($lambda = 10 upright(" panggilan per jam")$).

#block[
#set enum(numbering: "a.", start: 1)
+ Berapa probabilitas terdapat tepat 5 panggilan dalam 1 jam?
+ Berapa probabilitas terdapat 3 atau kurang panggilan dalam 1 jam?
+ Berapa probabilitas terdapat tepat 15 panggilan dalam 2 jam?
+ Berapa probabilitas terdapat tepat 5 panggilan dalam 30 menit?
]

#strong[Jawaban:] a. $P \( X = 5 \; lambda t = 10 \) = frac(e^(- 10) 10^5, 5 !) = 0 \, 037833$ b. $P \( X lt.eq 3 \) = F \( 3 \) = sum_(x = 0)^3 frac(e^(- 10) 10^x, x !) = 0 \, 010336$ c.~$P \( X = 15 \; lambda t = 20 \) = f \( 15 \) = frac(e^(- 20) 20^15, 15 !) = 0 \, 051649$ d.~$P \( X = 5 \; lambda t = 5 \) = f \( 5 \) = frac(e^(- 5) 5^5, 5 !) = 0 \, 175467$

#horizontalrule

== #strong[Soal 3]
<soal-3>
Jumlah permukaan cacat pada panel plastik yang digunakan dalam interior mobil memiliki distribusi Poisson dengan mean 0,05 cacat per $upright("ft")^2$. Asumsikan suatu interior mobil mengandung 10 $upright("ft")^2$ panel plastik.

#block[
#set enum(numbering: "a.", start: 1)
+ Berapa probabilitas tidak terdapat cacat permukaan pada interior mobil?
+ Jika sepuluh mobil dijual, berapa probabilitas dari sepuluh mobil tersebut tidak ada yang memiliki cacat permukaan?
+ Jika sepuluh mobil dijual, berapa probabilitas paling banyak satu mobil yang memiliki cacat permukaan?
+ Jika 100 Panel diperiksa, berapa probabilitas lebih sedikit dari 5 panel memiliki cacat permukaan?
]

#strong[Jawaban:] a. Misalkan $X$ adalah jumlah cacat permukaan pada interior mobil ($mu = 0 \, 05 times 10 = 0 \, 5$). $ P \( X = 0 \) = f \( 0 \; 0 \, 5 \) = frac(e^(- 0 \, 5) 0 \, 5^0, 0 !) = 1 / sqrt(e) = 0 \, 60653 $ b. Mobil satu dan lainnya adalah independen sehingga kondisi ini memenuhi kriteria Proses Bernoulli. Misalkan $Y$ melambangkan jumlah mobil yang memiliki cacat permukaan: $ P \( Y = 0 \) = b \( 0 \; 10 \; 1 - 0 \, 60653 \) = 0 \, 006738 $ c.~Probabilitas paling banyak satu mobil cacat: $ P \( Y lt.eq 1 \) = sum_(y = 0)^1 b \( y \; 10 \; 1 - 0 \, 60653 \) = 0 \, 050448 $ d.~#strong[Asumsi 1:] Jika 1 panel adalah 1 $upright("ft")^2$ ($mu = 0 \, 05$) $P \( X = 0 \) = f \( 0 \; 0 \, 05 \) = frac(e^(- 0 \, 05) 0 \, 05^0, 0 !) = 0 \, 951229$ $P \( Y < 5 \) = sum_(y = 0)^4 b \( y \; 100 \; 1 - 0 \, 951229 \) = 0 \, 458378$ #strong[Asumsi 2:] Jika 1 panel adalah 10 $upright("ft")^2$ ($mu = 0 \, 5$) $P \( X = 0 \) = 0 \, 60653$ $P \( Y < 5 \) = sum_(y = 0)^4 b \( y \; 100 \; 1 - 0 \, 60653 \) = 1 \, 43 times 10^(- 16)$

#horizontalrule

== #strong[Soal 4]
<soal-4>
Sebuah bank meletakkan 5 set infrastruktur hardware di 5 data center untuk aplikasi #emph[Core Banking System] (CBS). Masing-masing set memiliki probabilitas bekerja dengan baik sebesar 0,8. Definisikan $X$ sebagai jumlah Data Center yang bekerja dengan baik.

#block[
#set enum(numbering: "a.", start: 1)
+ Buatlah tabel distribusi probabilitas #emph[random variable] $X$!
+ Gambarkan distribusi probabilitas #emph[random variable] $X$! #emph[\(Diasumsikan gambar mengikuti plot distribusi PMF Binomial)]
+ Gambarkan distribusi kumulatif #emph[random variable] $X$! #emph[\(Diasumsikan gambar mengikuti plot fungsi tangga CMF Binomial)]
+ Dengan melihat gambar distribusi kumulatif, estimasikan suatu nilai $M$ sehingga $P \( X lt.eq M \) = 0 \, 5$. Nilai $M$ ini disebut nilai median.
+ Tentukan mean dan variansi untuk #emph[random variable] $X$!
+ Tentukan probabilitas sistem down secara total!
+ Tentukan probabilitas sistem nyaris down secara total (tinggal 1 Data Center bekerja dengan baik)!
+ Tentukan probabilitas minimal 1 Data Center bekerja dengan baik!
]

#strong[Jawaban:] a. Tabel Distribusi Probabilitas $X tilde.op upright("Binomial") \( 5 \; 0 \, 8 \)$: | $x$ | $f \( x \)$ | |:---:|:---| | 0 | 0,00032 | | 1 | 0,0064 | | 2 | 0,0512 | | 3 | 0,2048 | | 4 | 0,4096 | | 5 | 0,32768 |

#block[
#set enum(numbering: "a.", start: 4)
+ $M = 3$ #emph[\(Sesuai perhitungan referensi kunci jawaban).]
+ $E \( X \) = mu = sum_(x = 0)^5 x f \( x \) = 4$. $E \( X^2 \) = sum_(x = 0)^5 x^2 f \( x \) = 16 \, 8$. $sigma^2 = E \( X^2 \) - mu^2 = 0 \, 8$.
+ $P \( X = 0 \) = F \( 0 \) = 0 \, 00032$.
+ $P \( X = 1 \) = f \( 1 \) = 0 \, 0064$.
+ $P \( X gt.eq 1 \) = 1 - P \( X < 1 \) = 1 - P \( X = 0 \) = 0 \, 99968$.
]

#horizontalrule

== #strong[Soal 5]
<soal-5>
Sebuah komponen memiliki umur $L$ yang diukur dalam hari, sedemikian sehingga $P \[ L = n \]$ dari kegagalan pada hari ke-$n$ mengikuti distribusi geometrik $P \[ L = n \] = \( 1 dash.en b \) b^n$\; untuk $n = 0 \, 1 \, 2 \, 3 \, dots.h$. Bila $b = 0 \, 6$:

#block[
#set enum(numbering: "a.", start: 1)
+ Gambarkan distribusi probabilitas dari #emph[random variable] $L$!
+ Gambarkan distribusi kumulatif dari #emph[random variable] $L$!
+ Estimasikan suatu nilai $M$ sehingga $P \( X lt.eq M \) = 0 \, 5$ (nilai median)!
+ Tentukan nilai ekspektasi (mean) untuk #emph[random variable] $L$!
+ Tentukan peluang kejadian $F_i$, yaitu kejadian bahwa tidak terjadi failure (kerusakan) sebelum hari ke-$i$.
]

#strong[Jawaban:] a & b. #emph[\(Grafik PMF akan menurun eksponensial dari n=0, dan CMF akan asimtotik ke nilai 1).] c.~$M = 0$ d.~$E \( L \) = sum_(n = 0)^oo n \( 1 - b \) b^n = frac(1 - b, 1 - b) = 1$ #emph[\(Sesuai kalkulasi sumber)] e. Tidak failure sebelum hari ke-$i$ berarti failure terjadi pada hari ke-$i$ sampai tak hingga. $ F_i = sum_(l = i)^oo f \( l \) = sum_(l = i)^oo \( 1 - b \) b^l = \( 1 - b \) sum_(l = i)^oo b^l = \( 1 - b \) frac(b^i, 1 - b) $ $ F_i = b^i \, quad i = 1 \, 2 \, dots.h $

#horizontalrule

== #strong[Soal 6]
<soal-6>
Tentukan range dari masing-masing #emph[random variable] berikut: a. Suatu timbangan elektrik menampilkan berat pada gram terdekatnya (maksimal 5 digit, lebih dari 99999 g ditampilkan sebagai 99999). b. Sebanyak 500 part mesin mengandung 10 part yang tidak sesuai. Diambil sampel 5 part. c.~Sebanyak 500 part mesin mengandung 10 part yang tidak sesuai. Diambil acak tanpa pengembalian sampai part yang tidak sesuai didapat.

#strong[Jawaban:] a. $R_X = { 0 \, 1 \, 2 \, dots.h \, 99999 }$ b. $R_X = { 0 \, 1 \, 2 \, 3 \, 4 \, 5 }$ c.~$R_X = { 1 \, 2 \, dots.h \, 491 }$

#horizontalrule

== #strong[Soal 7]
<soal-7>
Suatu sistem komunikasi mempunyai 4 jalur eksternal. Asumsikan probabilitas suatu jalur sedang digunakan saat observasi adalah 0,8. Tentukan ruang sampel dan gambarkan dalam tabel! Asumsikan jalur bersifat independen.

#strong[Jawaban:] Kasus ini memenuhi syarat Proses Bernoulli sehingga #emph[random variable] $X$ mengikuti distribusi binomial dengan $p = 0 \, 8$ dan $n = 4$. | $x$ | $f \( x \)$ | |:---:|:---| | 0 | 0,0016 | | 1 | 0,0256 | | 2 | 0,1536 | | 3 | 0,4096 | | 4 | 0,4096 |

#horizontalrule

== #strong[Soal 8]
<soal-8>
Dalam proses manufaktur semikonduktor, 3 wafer diuji independen. Peluang sebuah wafer lolos uji adalah 0,8.

#block[
#set enum(numbering: "a.", start: 1)
+ Tentukan PMF dan CMF dari jumlah wafer yang lolos uji!
+ Tentukan mean dari #emph[random variable] tersebut!
+ Tentukan variansi dari #emph[random variable] tersebut!
]

#strong[Jawaban:] Eksperimen ini memenuhi Bernoulli sehingga dimodelkan sebagai Binomial dengan $p = 0 \, 8$ dan $n = 3$. $ f \( x \) = b \( x \; 3 \; 0 \, 8 \) = binom(3, x) p^x q^(3 - x) \, quad x = 0 \, 1 \, 2 \, 3 $ a. Tabel Distribusi: | $x$ | $upright("PMF: ") f \( x \)$ | $upright("CMF: ") F \( x \)$ | |:---:|:---|:---| | 0 | 0,008 | 0,008 | | 1 | 0,096 | 0,104 | | 2 | 0,384 | 0,488 | | 3 | 0,512 | 1,000 |

#block[
#set enum(numbering: "a.", start: 2)
+ $mu_X = n p = 3 \( 0 \, 8 \) = 2 \, 4$
+ $sigma_X^2 = n p q = 3 \( 0 \, 8 \) \( 0 \, 2 \) = 0 \, 48$
]

#horizontalrule

== #strong[Soal 9]
<soal-9>
Jumlah kesalahan ketik dalam buku teks mengikuti distribusi Poisson dengan mean 0,01 kesalahan/halaman. Berapa probabilitas terdapat kurang dari atau sama dengan tiga kesalahan dalam 100 halaman?

#strong[Jawaban:] Distribusi Poisson dengan $lambda = 0 \, 01 upright(" kesalahan/halaman")$ dan $t = 100 upright(" halaman")$. $ mu = 0 \, 01 times 100 = 1 $ $ P \( X lt.eq 3 \) = sum_(x = 0)^3 frac(e^(- 1) 1^x, x !) = 0 \, 981 $

#horizontalrule

== #strong[Soal 10]
<soal-10>
Suatu persimpangan lampu sinyal memiliki peluang 20% hijau saat dilewati independen setiap pagi. a. Dalam 5 pagi, berapa probabilitas lampunya hijau hanya pada satu pagi saja? b. Dalam 20 pagi, berapa probabilitas lampunya hijau tepat empat kali? c.~Dalam 20 minggu, berapa probabilitas lampunya hijau lebih dari empat kali?

#strong[Jawaban:] Mengikuti distribusi Binomial karena memenuhi kriteria (independen, probabilitas konstan $p = 0 \, 2$, eksperimen berulang, 2 keluaran). a. $n = 5$. $ P \( X = 1 \) = b \( 1 \; 5 \; 0 \, 2 \) = 0 \, 4096 $ b. $n = 20$. $ P \( X = 4 \) = b \( 4 \; 20 \; 0 \, 2 \) = 0 \, 2182 $ c.~$n = 20 times 7 = 140 upright(" hari")$. #emph[\(Berdasarkan perhitungan dari dokumen rujukan).] $ P \( X = 4 \) = b \( 4 \; 140 \; 0 \, 2 \) = 1 \, 6214 times 10^(- 9) $
