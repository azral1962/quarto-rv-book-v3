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
  title: [Problem Set 3: Probabilitas dan Statistik],
  subtitle: [Lembar Soal dan Jawaban Lengkap],
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
Misalkan $X$ adalah #emph[random variable] diskrit dengan PMF: $ P \( X = x \) = cases(delim: "{", 0 \, 1 & upright("untuk ") x = 0 \, 2, 0 \, 2 & upright("untuk ") x = 0 \, 4, 0 \, 2 & upright("untuk ") x = 0 \, 5, 0 \, 3 & upright("untuk ") x = 0 \, 8, 0 \, 2 & upright("untuk ") x = 1, 0 & upright("lainnya")) $

#block[
#set enum(numbering: "a.", start: 1)
+ Tentukan $R_x$, range dari #emph[random variable] $X$!
+ Tentukan $P \( X lt.eq 0 \, 5 \)$!
+ Tentukan $P \( 0 \, 25 < X < 0 \, 75 \)$!
+ Tentukan $P \( X = 0 \, 2 divides X < 0 \, 6 \)$!
+ Tentukan $mu$ dan $sigma^2$!
]

#strong[Jawaban:] a. $R_x = { 0 \, 2 \; 0 \, 4 \; 0 \, 5 \; 0 \, 8 \; 1 }$ b. $P \( X lt.eq 0 \, 5 \) = P \( 0 \, 2 \) + P \( 0 \, 4 \) + P \( 0 \, 5 \) = 0 \, 1 + 0 \, 2 + 0 \, 2 = 0 \, 5$ c.~$P \( 0 \, 25 < X < 0 \, 75 \) = P \( 0 \, 4 \) + P \( 0 \, 5 \) + P \( 0 \, 8 \) = 0 \, 2 + 0 \, 2 + 0 \, 3 = 0 \, 7$ #emph[\(Sesuai dengan teks sumber, terdapat penyertaan P(0,8) dalam perhitungan).] d.~$P \( X = 0 \, 2 divides X < 0 \, 6 \) = frac(P \( X = 0 \, 2 sect X < 0 \, 6 \), P \( X < 0 \, 6 \)) = frac(0 \, 1, 0 \, 1 + 0 \, 2 + 0 \, 2) = frac(0 \, 1, 0 \, 5) = 0 \, 2$ e. $mu = sum x P \( x \) = \( 0 \, 2 \) \( 0 \, 1 \) + \( 0 \, 4 \) \( 0 \, 2 \) + \( 0 \, 5 \) \( 0 \, 2 \) + \( 0 \, 8 \) \( 0 \, 3 \) + \( 1 \) \( 0 \, 2 \) = 0 \, 64$ $sigma^2 = E \( X^2 \) - mu^2 = 0 \, 478 - 0 \, 64^2 = 0 \, 0684$

#horizontalrule

== #strong[Soal 2]
<soal-2>
Diketahui fungsi distribusi #emph[random variable] diskrit $X$ adalah: $ F \( x \) = cases(delim: "{", 0 \, & x < - 1, 0 \, 2 \, & - 1 lt.eq x < 0, 0 \, 5 \, & 0 lt.eq x < 1, 0 \, 8 \, & 1 lt.eq x < 3, 1 \, & x gt.eq 3) $ a. Gambarkan grafik $F \( x \)$! b. Tentukan fungsi massa probabilitas (PMF) untuk $X$! c.~Hitung $P \( X < 1 \)$, $P \( 0 < X lt.eq 3 \)$, $P \( 0 lt.eq X < 3 \)$, $P \( 0 < X < 3 \)$, dan $P \( 0 lt.eq X lt.eq 3 \)$!

#strong[Jawaban:] a. Grafik $F \( x \)$ adalah grafik fungsi tangga (step-function) yang nilainya naik pada titik $x in { - 1 \, 0 \, 1 \, 3 }$. b. $P \( X = - 1 \) = 0 \, 2$\; $P \( X = 0 \) = 0 \, 5 - 0 \, 2 = 0 \, 3$\; $P \( X = 1 \) = 0 \, 8 - 0 \, 5 = 0 \, 3$\; $P \( X = 3 \) = 1 - 0 \, 8 = 0 \, 2$. c.~$P \( X < 1 \) = F \( 0 \) = 0 \, 5$. $P \( 0 < X lt.eq 3 \) = F \( 3 \) - F \( 0 \) = 1 - 0 \, 5 = 0 \, 5$. $P \( 0 lt.eq X < 3 \) = P \( X = 0 \) + P \( X = 1 \) = 0 \, 3 + 0 \, 3 = 0 \, 6$. $P \( 0 < X < 3 \) = P \( X = 1 \) = 0 \, 3$. $P \( 0 lt.eq X lt.eq 3 \) = P \( X = 0 \) + P \( X = 1 \) + P \( X = 3 \) = 0 \, 3 + 0 \, 3 + 0 \, 2 = 0 \, 8$.

#horizontalrule

== #strong[Soal 3]
<soal-3>
Misalkan #emph[random variable] $X$ mempunyai fungsi distribusi: $ F \( x \) = cases(delim: "{", 0 & x lt.eq 0, 1 - e^(- x^2) & x > 0) $ Berapa probabilitas $X$ melebihi 1?

#strong[Jawaban:] $P \( X > 1 \) = 1 - P \( X lt.eq 1 \) = 1 - F \( 1 \) = 1 - \( 1 - e^(- 1^2) \) = e^(- 1) = 0 \, 3679 dots.h$

#horizontalrule

== #strong[Soal 4]
<soal-4>
Tentukan range dari masing-masing #emph[random variable] berikut: a. Suatu timbangan elektrik menampilkan berat pada gram terdekatnya. Timbangan ini hanya menampilkan 5 digit saja. Semua berat yang lebih dari nilai tersebut (99999 g) akan ditampilkan sebagai 99999. #emph[Random variable] nya adalah berat yang ditampilkan. b. Sebanyak 500 part mesin mengandung 10 part yang tidak sesuai. #emph[Random variable] nya adalah jumlah part dari sampling sebanyak 5 part yang tidak sesuai. c.~Sebanyak 500 part mesin mengandung 10 part yang tidak sesuai. Part tersebut dipilih secara acak tanpa pengembalian, sampai part yang tidak sesuai didapat. #emph[Random variable] nya adalah jumlah part yang terambil.

#strong[Jawaban:] a. $R_x = { 0 \, 1 \, 2 \, dots.h \, 99999 }$ b. $R_x = { 0 \, 1 \, 2 \, 3 \, 4 \, 5 }$ c.~$R_x = { 1 \, 2 \, 3 \, dots.h \, 491 }$ #emph[\(Paling apes mengambil 490 part baik berturut-turut, part ke-491 pasti part cacat)].

#horizontalrule

== #strong[Soal 5]
<soal-5>
Suatu sistem komunikasi untuk bisnis mempunyai 4 jalur eksternal. Asumsikan probabilitas suatu jalur sedang digunakan saat observasi adalah 0,8. Tentukan ruang sampel dari observasi tersebut! Gambarkan dalam tabel!

#strong[Jawaban:] Ini adalah Distribusi Binomial dengan $n = 4 \, p = 0 \, 8$. Rentang ruang sampel $R_x = { 0 \, 1 \, 2 \, 3 \, 4 }$. PMF: $P \( X = x \) = binom(4, x) \( 0 \, 8 \)^x \( 0 \, 2 \)^(4 - x)$. | $x$ | $P \( X = x \)$ | |:---:|:---| | 0 | 0,0016 | | 1 | 0,0256 | | 2 | 0,1536 | | 3 | 0,4096 | | 4 | 0,4096 |

#horizontalrule

== #strong[Soal 6]
<soal-6>
Divisi Marketing memperkirakan alat baru akan sangat berhasil (0,3), berhasil (0,6), atau tidak berhasil (0,1). Pendapatan tahunan berkaitan adalah Rp. 100 milyar, Rp. 50 milyar, dan Rp. 10 milyar. Tentukan PMF dari $X$!

#strong[Jawaban:] $ f \( x \) = cases(delim: "{", 0 \, 1 & upright("untuk ") x = 10 upright(" milyar"), 0 \, 6 & upright("untuk ") x = 50 upright(" milyar"), 0 \, 3 & upright("untuk ") x = 100 upright(" milyar")) $

#horizontalrule

== #strong[Soal 7]
<soal-7>
Perusahaan manufaktur disk drive memperkirakan storage 1TB, 500GB, dan 100GB akan terjual dengan probabilitas 0,5; 0,3; dan 0,2 dengan pendapatan sebesar Rp. 500 milyar, Rp. 250 milyar, dan Rp. 100 milyar. Tentukan PMF dari $X$!

#strong[Jawaban:] $ f \( x \) = cases(delim: "{", 0 \, 2 & upright("untuk ") x = 100 upright(" milyar"), 0 \, 3 & upright("untuk ") x = 250 upright(" milyar"), 0 \, 5 & upright("untuk ") x = 500 upright(" milyar")) $

#horizontalrule

== #strong[Soal 8]
<soal-8>
Diketahui fungsi padat probabilitas (density function) dari #emph[random variable] kontinu $X$ adalah: $ f \( x \) = cases(delim: "{", k x \, & 0 lt.eq x lt.eq 4, 0 \, & x upright(" lainnya")) $ a. Hitung nilai $k$! b. Hitung $F \( x \)$! c.~Hitung $P \( X < 1 \/ 2 \)$ dan $P \( 1 \/ 2 < X < 1 \)$!

#strong[Jawaban:] a. $integral_0^4 k x d x = 1 arrow.r.double.long 8 k = 1 arrow.r.double.long k = 1 / 8 = 0 \, 125$ b. $F \( x \) = integral_0^x 1 / 8 t d t = x^2 / 16$ untuk $0 lt.eq x lt.eq 4$. c.~$P \( X < 1 \/ 2 \) = F \( 1 \/ 2 \) = 1 / 64$. $P \( 1 \/ 2 < X < 1 \) = F \( 1 \) - F \( 1 \/ 2 \) = 1 / 16 - 1 / 64 = 3 / 64$.

#horizontalrule

== #strong[Soal 9]
<soal-9>
Running time algoritma komputasi tertentu $R$ minimal adalah satu unit waktu dan peluang $R > 10$ adalah 0,5. Tentukan probabilitas bahwa running time melebihi 1000 unit waktu! Diasumsikan $R$ mengikuti distribusi Pareto $F \( r \) = 1 - \( r_m \/ r \)^alpha$.

#strong[Jawaban:] Diketahui $P \( R lt.eq 10 \) = F \( 10 \) = 0 \, 5$. Maka $1 - \( 1 \/ 10 \)^alpha = 0 \, 5 arrow.r.double.long 10^(- alpha) = 0 \, 5 arrow.r.double.long alpha = - log 0 \, 5$. Probabilitas $P \( R > 1000 \) = 1 - F \( 1000 \) = \( 1 \/ 1000 \)^(- log 0 \, 5) = 0 \, 125$.

#horizontalrule

== #strong[Soal 10]
<soal-10>
Probabilitas fungsi kepadatan dari berat bersih pada sebuah paket senyawa kimia adalah $f \( x \) = 2 \, 0$ untuk setiap nilai $49 \, 75 < x < 50 \, 25$. a. Tentukan probabilitas untuk paket memiliki berat lebih dari 50 pounds. b. Berapa banyak senyawa kimia yang terkandung dalam 90% dari keseluruhan paket?

#strong[Jawaban:] a. $P \( X > 50 \) = 1 - F \( 50 \) = 1 - integral_(49 \, 75)^50 2 d t = 1 - 0 \, 5 = 0 \, 5$. b. Misalkan banyaknya senyawa dalam 90% paket adalah $Y = 0 \, 9 X$. Maka $X = 1 \, 11111 Y$. Batasnya menjadi: $49 \, 75 < 1 \, 11111 y < 50 \, 25 arrow.r.double.long 44 \, 775 < y < 47 \, 25$.

#horizontalrule

== #strong[Soal 11]
<soal-11>
Diketahui fungsi distribusi kontinu $F \( x \) = 0 \, 2 x$ (untuk $0 lt.eq x < 4$) dan $F \( x \) = 0 \, 04 x + 0 \, 64$ (untuk $4 lt.eq x < 9$). a. Tentukan nilai $E \( X \)$! b. Tentukan nilai $P \( X gt.eq 6 \)$!

#strong[Jawaban:] a. $f \( x \) = 0 \, 2$ pada $x in \[ 0 \, 4 \)$ dan $0 \, 04$ pada $x in \[ 4 \, 9 \)$. $E \( X \) = integral_0^4 x \( 0 \, 2 \) d x + integral_4^9 x \( 0 \, 04 \) d x = 1 \, 6 + 1 \, 3 = 2 \, 9$. b. $P \( X gt.eq 6 \) = 1 - F \( 6 \) = 1 - \( 0 \, 04 \( 6 \) + 0 \, 64 \) = 0 \, 12$.

#horizontalrule

== #strong[Soal 12]
<soal-12>
Dalam proses manufaktur semikonduktor, 3 wafer diuji. Asumsi probabilitas lolos uji adalah 0,8 independen. Tentukan PMF, CMF, mean, dan variansi dari jumlah wafer lolos uji!

#strong[Jawaban:] $X tilde.op upright("Binomial") \( n = 3 \, p = 0 \, 8 \)$. PMF: $P \( 0 \) = 0 \, 008 \; P \( 1 \) = 0 \, 096 \; P \( 2 \) = 0 \, 384 \; P \( 3 \) = 0 \, 512$. CMF: $F \( 0 \) = 0 \, 008 \; F \( 1 \) = 0 \, 104 \; F \( 2 \) = 0 \, 488 \; F \( 3 \) = 1 \, 000$. Mean: $mu = n p = 3 \( 0 \, 8 \) = 2 \, 4$. Variansi: $sigma^2 = n p q = 3 \( 0 \, 8 \) \( 0 \, 2 \) = 0 \, 48$.

#horizontalrule

== #strong[Soal 13]
<soal-13>
Maskapai menjual 125 tiket untuk 120 penumpang. Probabilitas tidak datang 0,1 independen. a. Berapa probabilitas setiap penumpang yang datang mendapat penerbangan? b. Berapa probabilitas berangkat dengan kursi kosong?

#strong[Jawaban:] Probabilitas datang $p = 0 \, 9$. $X tilde.op upright("Binomial") \( 125 \, 0 \, 9 \)$. a. Probabilitas semua yang datang dapat kursi setara dengan penumpang datang $lt.eq 120$: $P \( X lt.eq 120 \) = sum_(x = 0)^120 binom(125, x) \( 0 \, 9 \)^x \( 0 \, 1 \)^(125 - x)$. b. Berangkat dengan kursi kosong setara dengan penumpang datang $lt.eq 119$: $P \( X lt.eq 119 \) = sum_(x = 0)^119 binom(125, x) \( 0 \, 9 \)^x \( 0 \, 1 \)^(125 - x)$.

#horizontalrule

== #strong[Soal 14]
<soal-14>
Panggilan telepon Poisson $lambda = 10$/jam. Berapa probabilitas terdapat: a) 5 panggilan/1 jam, b) $lt.eq 3$ panggilan/1 jam, c) 15 panggilan/2 jam, d) 5 panggilan/30 menit?

#strong[Jawaban:] a. $mu = 10 arrow.r.double.long P \( X = 5 \) = frac(e^(- 10) 10^5, 5 !) approx 0 \, 0378$. b. $mu = 10 arrow.r.double.long P \( X lt.eq 3 \) = sum_(x = 0)^3 frac(e^(- 10) 10^x, x !) approx 0 \, 0103$. c.~$mu = 20 arrow.r.double.long P \( X = 15 \) = frac(e^(- 20) 20^15, 15 !) approx 0 \, 0516$. d.~$mu = 5 arrow.r.double.long P \( X = 5 \) = frac(e^(- 5) 5^5, 5 !) approx 0 \, 1755$.

#horizontalrule

== #strong[Soal 15]
<soal-15>
Cacat Poisson 0,05 per ft$""^2$. Interior = 10 ft$""^2$. a. Probabilitas tidak ada cacat 1 mobil? b. 10 mobil dijual, probabilitas 0 mobil cacat? c.~10 mobil dijual, maksimal 1 cacat? d.~100 panel diperiksa, probabilitas $< 5$ panel cacat?

#strong[Jawaban:] a. $mu = 0 \, 05 times 10 = 0 \, 5$. $P \( X = 0 \) = e^(- 0 \, 5) approx 0 \, 6065$. b. $X tilde.op upright("Binomial") \( 10 \, 0 \, 3935 \)$ dimana $p \( upright("cacat") \) = 1 - 0 \, 6065 = 0 \, 3935$. $P \( Y = 0 \) = \( 0 \, 6065 \)^10 approx 0 \, 0067$. c.~$P \( Y lt.eq 1 \) = binom(10, 0) \( 0 \, 6065 \)^10 + binom(10, 1) \( 0 \, 3935 \)^1 \( 0 \, 6065 \)^9 approx 0 \, 0504$. d.~Jika 1 panel = 10 ft$""^2$, $Y tilde.op upright("Binomial") \( 100 \, 0 \, 3935 \)$. $P \( Y lt.eq 4 \) = sum_(y = 0)^4 binom(100, y) \( 0 \, 3935 \)^y \( 0 \, 6065 \)^(100 - y)$.

#horizontalrule

== #strong[Soal 16]
<soal-16>
Bank menaruh 5 hardware Data Center. Peluang hidup $p = 0 \, 8$. $X$ = jumlah DC hidup. a. Tabel distribusi dan CMF? b. Nilai median $M$? c.~Mean dan variansi? d.~Probabilitas down total, tinggal 1, dan minimal 1?

#strong[Jawaban:] a. $X tilde.op upright("Bin") \( 5 \, 0 \, 8 \)$. PMF: $P \( 0 \) = 0 \, 00032 \; P \( 1 \) = 0 \, 0064 \; P \( 2 \) = 0 \, 0512 \; P \( 3 \) = 0 \, 2048 \; P \( 4 \) = 0 \, 4096 \; P \( 5 \) = 0 \, 32768$. b. $M = 4$ (Karena CMF pada $X = 3$ adalah 0,26272, dan baru meloncat melewati 0,5 pada $X = 4$ yaitu 0,67232). c.~Mean = $n p = 4$. Variansi = $n p q = 0 \, 8$. d.~Down total $P \( X = 0 \) = 0 \, 00032$. Tinggal satu $P \( X = 1 \) = 0 \, 0064$. Minimal satu $P \( X gt.eq 1 \) = 1 - 0 \, 00032 = 0 \, 99968$.

#horizontalrule

== #strong[Soal 17]
<soal-17>
Geometrik $P \( L = n \) = \( 1 - b \) b^n$, $b = 0 \, 6$. Tentukan Median $M$, Mean, dan peluang tidak rusak sebelum hari ke-$i$ ($F_i$).

#strong[Jawaban:] Mean $E \( L \) = frac(b, 1 - b) = 1 \, 5$. Median $M = 1$ (CMF melewati 0,5 pada hari ke-1). Peluang tidak rusak (Survival): $P \( L gt.eq i \) = sum_(n = i)^oo \( 0 \, 4 \) \( 0 \, 6 \)^n = \( 0 \, 6 \)^i$.

#horizontalrule

== #strong[Soal 18]
<soal-18>
Sesi FTP $L gt.eq t_0$. $P \( L > 2 t_0 \) = 4 P \( L > 4 t_0 \)$ dengan PDF $f \( l \) = a t_0^a l^(- a - 1)$. Tentukan probabilitas melebihi $10 t_0$.

#strong[Jawaban:] CDF Pareto Survival $P \( L > l \) = \( t_0 \/ l \)^a$. Maka $\( t_0 \/ 2 t_0 \)^a = 4 \( t_0 \/ 4 t_0 \)^a arrow.r.double.long \( 1 \/ 2 \)^a = 4 \( 1 \/ 4 \)^a arrow.r.double.long \( 1 \/ 2 \)^a = 4 \( 1 \/ 2 \)^(2 a) arrow.r.double.long \( 1 \/ 2 \)^(- a) = 4 arrow.r.double.long a = 2$. Probabilitas $P \( L > 10 t_0 \) = \( 1 \/ 10 \)^2 = 0 \, 01$.

#horizontalrule

== #strong[Soal 19]
<soal-19>
Kereta tiba setiap 15 menit. Penumpang tiba berdistribusi seragam 07.00 - 07.30. Peluang menunggu $< 5$ menit?

#strong[Jawaban:] Kereta berangkat pada 07.00, 07.15, 07.30. Agar menunggu $< 5$ menit, penumpang harus tiba di rentang (07.10-07.15) atau (07.25-07.30). Luas rentang sukses = 5 menit + 5 menit = 10 menit. Total rentang = 30 menit. Probabilitas = $10 \/ 30 = 1 \/ 3$.

#horizontalrule

== #strong[Soal 20]
<soal-20>
Typo Poisson $lambda = 0 \, 01$/halaman. Probabilitas $lt.eq 3$ kesalahan per 100 halaman?

#strong[Jawaban:] Untuk 100 halaman, $mu = 0 \, 01 times 100 = 1$. $P \( X lt.eq 3 \) = e^(- 1) \( 1 + 1 + 1 \/ 2 + 1 \/ 6 \) = e^(- 1) \( 8 \/ 3 \) approx 0 \, 981$.

#horizontalrule

== #strong[Soal 21]
<soal-21>
Lampu hijau $p = 0 \, 2$. a. 5 hari, tepat 1 kali hijau? b. 20 hari, tepat 4 hijau? c.~20 minggu (140 hari), lebih 4 kali hijau?

#strong[Jawaban:] a. $binom(5, 1) \( 0 \, 2 \)^1 \( 0 \, 8 \)^4 approx 0 \, 4096$. b. $binom(20, 4) \( 0 \, 2 \)^4 \( 0 \, 8 \)^16 approx 0 \, 2182$. c.~$P \( X > 4 \) = 1 - P \( X lt.eq 4 \) = 1 - sum_(x = 0)^4 binom(140, x) \( 0 \, 2 \)^x \( 0 \, 8 \)^(140 - x)$.

#horizontalrule

== #strong[Soal 22]
<soal-22>
2% cacat. Berapa order disimpan agar 100 sukses dengan probabilitas $gt.eq 0 \, 95$?

#strong[Jawaban:] $X tilde.op upright("Negatif Binomial")$. Menggunakan pendekatan normal, dibutuhkan $N$ komponen sedemikian hingga area kelolosan $n gt.eq 100$ probabilitasnya $> 0 \, 95$. Persamaan invers normal menghasilkan $N approx 103$.

#horizontalrule

== #strong[Soal 23]
<soal-23>
Umur aki Eksponensial $mu = 10.000$. Peluang bertahan perjalanan 5.000 km?

#strong[Jawaban:] Karena eksponensial bersifat memoryless, $P \( X > 5000 \) = e^(- 5000 \/ 10000) = e^(- 0 \, 5) approx 0 \, 6065$.
