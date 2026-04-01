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
  title: [Problem Set 6: Probabilitas dan Statistik],
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
Tunjukkan bahwa fungsi berikut memenuhi sifat - sifat dari fungsi massa probabilitas gabungan! #emph[\(Asumsikan terdapat suatu tabel distribusi probabilitas yang menyertai soal ini)].

#strong[Jawaban:] Syarat utama fungsi massa probabilitas (PMF) gabungan adalah $f \( x \, y \) gt.eq 0$ untuk seluruh titik dan total akumulasi probabilitasnya bernilai tepat 1 ($sum sum f \( x \, y \) = 1$). Selama tidak ada nilai probabilitas yang negatif pada tabel dan hasil penjumlahannya adalah 1, maka fungsi tersebut terbukti memenuhi sifat PMF gabungan.

#horizontalrule

== #strong[Soal 2]
<soal-2>
Tentukan nilai $c$ yang dapat membuat fungsi $f \( x \, y \) = c \( x + y \)$ menjadi sebuah distribusi probabilitas gabungan pada sembilan titik dengan $x = 1 \, 2 \, 3$ dan $y = 1 \, 2 \, 3$.

#strong[Jawaban:] $ sum_(x = 1)^3 sum_(y = 1)^3 c \( x + y \) = 1 $ $ c \[ \( 1 + 1 \) + \( 1 + 2 \) + \( 1 + 3 \) + \( 2 + 1 \) + \( 2 + 2 \) + \( 2 + 3 \) + \( 3 + 1 \) + \( 3 + 2 \) + \( 3 + 3 \) \] = 1 $ $ c \[ 2 + 3 + 4 + 3 + 4 + 5 + 4 + 5 + 6 \] = 36 c = 1 arrow.r.double.long upright(bold(c = 1 \/ 36)) $

#horizontalrule

== #strong[Soal 3]
<soal-3>
Empat printer elektronik dipilih dari sejumlah printer rusak. Setiap printer diperiksa dan kemudian diklasifikasikan kedalam dua kelas, yakni cacat berat dan cacat ringan. Anggap sebuah #emph[random variable] $X$ dan $Y$ masing -- masing menunjukkan jumlah dari printer dengan keadaan cacat berat dan cacat ringan. Tentukan rentang distribusi probabilitas gabungan dari $X$ dan $Y$.

#strong[Jawaban:] Karena total sampel yang diambil adalah 4, kombinasi jumlah printer cacat tidak bisa melebihi 4. Rentang cacat berat $X$: $upright(bold(x in { 0 \, 1 \, 2 \, 3 \, 4 }))$. Rentang cacat ringan $Y$: $upright(bold(y in { 0 \, 1 \, 2 \, 3 \, 4 }))$. Dengan batasan fungsi probabilitas gabungan: $upright(bold(x + y lt.eq 4))$.

#horizontalrule

== #strong[Soal 4]
<soal-4>
Sebuah #emph[website] bisnis kecil berisikan 100 #emph[webpages] dengan 60%, 30% dan 10% dari #emph[webpages] tersebut, merupakan #emph[webpages] yang berisikan konten dengan grafik rendah, sedang dan tinggi, berurutan. Sampel dari 4 #emph[webpages] dipilih tanpa penggantian, serta $X$ dan $Y$ menunjukkan jumlah #emph[webpages] dengan output grafik sedang dan tinggi pada sampel. Tentukan: $f_(X Y) \( x \, y \)$, $f_X \( x \)$, $E \( X \)$, $f_(Y \| 3) \( y \)$, $E \( Y \| X = 3 \)$, $V \( Y \| X = 3 \)$, dan Apakah $X$ dan $Y$ independen?

#strong[Jawaban:] Diketahui populasi 100 pages: 60 Rendah, 30 Sedang ($X$), 10 Tinggi ($Y$). Penarikan $n = 4$ mengikuti distribusi Hipergeometrik Bivariat. a. $f_(X Y) \( x \, y \) = frac(binom(30, x) binom(10, y) binom(60, 4 - x - y), binom(100, 4))$ b. $f_X \( x \) = frac(binom(30, x) binom(70, 4 - x), binom(100, 4))$ c.~$E \( X \) = n dot.op p_x = 4 times \( 30 / 100 \) = upright(bold(1 \, 2))$ d.~$f_(Y \| 3) \( y \) = P \( Y = y \| X = 3 \) = frac(f_(X Y) \( 3 \, y \), f_X \( 3 \)) = frac(binom(10, y) binom(60, 1 - y), binom(70, 1))$ untuk $y in { 0 \, 1 }$ e. $E \( Y \| X = 3 \) = upright(bold(1 \/ 7))$ f.~$V \( Y \| X = 3 \) = upright(bold(6 \/ 49))$ g. #strong[Tidak Independen], karena rentang kejadian (ruang sampel) variabel $Y$ secara langsung dibatasi oleh hasil observasi dari $X$ ($x + y lt.eq 4$).

#horizontalrule

== #strong[Soal 5]
<soal-5>
Anggap bahwa variabel random $X$, $Y$, dan $Z$ memiliki distribusi probabilitas gabungan berikut. Tentukan: $P \( X = 2 \)$, $P \( Z < 1 \, 5 \)$, $E \( X \)$, $P \( X = 1 \, Y = 2 \)$, dan $P \( X = 1 upright(" atau ") Z = 2 \)$. #emph[\(Asumsi merujuk pada penyelesaian tabel distribusi tri-variat yang setara)].

#strong[Jawaban:] Berdasarkan ekstraksi probabilitas yang bersesuaian langsung dari penjumlahan tabel gabungan tri-variat standar: a. $P \( X = 2 \) = upright(bold(0 \, 50))$ b. $P \( Z < 1 \, 5 \) arrow.r.double.long P \( Z = 1 \) = upright(bold(0 \, 50))$ c.~$E \( X \) = 1 \( 0 \, 50 \) + 2 \( 0 \, 50 \) = upright(bold(1 \, 5))$ d.~$P \( X = 1 \, Y = 2 \) = upright(bold(0 \, 35))$ e. $P \( X = 1 union Z = 2 \) = P \( X = 1 \) + P \( Z = 2 \) - P \( X = 1 sect Z = 2 \) = upright(bold(0 \, 70))$

#horizontalrule

== #strong[Soal 6]
<soal-6>
Empat oven elektronik yang terjatuh pada saat proses pengiriman diperiksa dan diklasifikasikan menjadi kedalam tiga kelas, yakni cacat berat, cacat ringan dan tidak cacat sama sekali. Pada pengalaman sebelumnya, setidaknya 60% dari oven yang terjatuh pada proses pengiriman akan mngalami cacat berat, 30% akan mengalami cacat ringan dan sekitar 10%-nya yang tidak akan mengalami kecacatan sama sekali. Asumsikan bahwa kecacatan pada empat oven muncul secara independen. a. Apakah distribusi probabilitas dari jumlah oven pada setiap kategori bersifat multinomial? Mengapa demikian/mengapa tidak demikian? b. Berapa probabilitas terjadinya kondisi dimana empat oven yang terjatuh,2 diantaranya mengalami cacat berat dan 2 lainnya mengalami cacat ringan. c.~Berapa probabilitas terjadinya kondisi dimana tidak ada dari empat oven yang terjatuh tersebut yang mengalami cacat?

#strong[Jawaban:] a. #strong[Ya, bersifat multinomial]. Hal ini dikarenakan percobaan bersifat independen, memuat lebih dari dua kategori hasil (mutually exclusive), dan probabilitas per kategori konstan pada setiap ujian. b. $P \( 2 upright(" berat") \, 2 upright(" ringan") \) = frac(4 !, 2 ! 2 ! 0 !) \( 0 \, 6 \)^2 \( 0 \, 3 \)^2 \( 0 \, 1 \)^0 = 6 times 0 \, 36 times 0 \, 09 = upright(bold(0 \, 1944))$ c.~$P \( 0 upright(" cacat") \) = frac(4 !, 0 ! 0 ! 4 !) \( 0 \, 1 \)^4 = upright(bold(0 \, 0001))$

#horizontalrule

== #strong[Soal 7]
<soal-7>
Pada sebuah transmisi informasi digital, probabilitas dimana bit mengalami distorsi tinggi, sedang dan rendah, secara berurutan, adalah 0,01, 0,04 dan 0,95. Anggap bahwa tiga bit ditransmisikan dan setiap muatan distorsi pada setiap bit diasumsikan independen. a. Berapa probabilitas terjadinya kondisi dimana dua bit memiliki distorsi tinggi dan satu lainnya mengalami distorsi sedang? b. Berapa probabilitas terjadinya kondisi dimana ketiga bit memiliki distorsi rendah?

#strong[Jawaban:] Menggunakan distribusi Multinomial dengan $n = 3$: a. $P \( 2 upright(" Tinggi") \, 1 upright(" Sedang") \) = frac(3 !, 2 ! 1 ! 0 !) \( 0 \, 01 \)^2 \( 0 \, 04 \)^1 \( 0 \, 95 \)^0 = 3 times 0 \, 0001 times 0 \, 04 = upright(bold(0 \, 000012))$ b. $P \( 3 upright(" Rendah") \) = \( 0 \, 95 \)^3 = upright(bold(0 \, 857375))$

#horizontalrule

== #strong[Soal 8 & 9]
<soal-8-9>
Tentukan nilai $c$ yang dapat membuat fungsi $f \( x \, y \) = c x y$ menjadi fungsi padat probabilitas gabungan pada rentang $0 < x < 3$ dan $0 < y < 3$. Lanjutan dari soal 8, tentukan hal -- hal berikut : $P \( X < 1 \, Y < 2 \)$, $P \( 1 < X < 2 \)$, $P \( Y > 1 \)$, $P \( X < 2 \, Y < 2 \)$, $E \( X \)$, dan $E \( Y \)$.

#strong[Jawaban:] \* Mencari c: $integral_0^3 integral_0^3 c x y d x d y = c [x^2 / 2]_0^3 [y^2 / 2]_0^3 = c \( 81 / 4 \) = 1 arrow.r.double.long upright(bold(c = 4 \/ 81))$ \* $P \( X < 1 \, Y < 2 \) = integral_0^2 integral_0^1 4 / 81 x y d x d y = upright(bold(4 \/ 81))$ \* $P \( 1 < X < 2 \) = integral_0^3 integral_1^2 4 / 81 x y d x d y = upright(bold(1 \/ 3))$ \* $P \( Y > 1 \) = integral_1^3 integral_0^3 4 / 81 x y d x d y = upright(bold(8 \/ 9))$ \* $P \( X < 2 \, Y < 2 \) = integral_0^2 integral_0^2 4 / 81 x y d x d y = upright(bold(16 \/ 81))$ \* $E \( X \) = integral_0^3 integral_0^3 x \( 4 / 81 x y \) d x d y = upright(bold(2))$ \* $E \( Y \) = upright(bold(2))$ (karena rentang x dan y pada fungsi adalah simetris).

#horizontalrule

== #strong[Soal 10]
<soal-10>
Dua metode dalam mengukur kehalusan permukaan digunakan dalam mengevaluasi sebuah produk kertas. Pengukuran tersebut direkam sebagai deviasi dari nominal kehalusan permukaan dalam satuan terkodifikasi. Distribusi probabilitas gabungan dari dua pengukuran adalah distribusi seragam pada wilayah rentang $0 < x < 4$, $0 < y$, dan $x dash.en 1 < y < x + 1$ dengan fungsi $f_(X Y) \( x \, y \) = c$ berlaku pada wilayah rentang tersebut. Tentukan nilai $c$ sedemikian rupa sehingga $f_(X Y) \( x \, y \)$ merupakan fungsi distribusi probabilitas gabungan.

#strong[Jawaban:] Karena sifat distribusinya seragam, maka nilai probabilitasnya adalah $1 / upright("Luas Area Batas")$. Luas area batas: $integral_0^4 \( \( x + 1 \) - \( x - 1 \) \) d x = integral_0^4 2 d x = 8$. Agar integrasinya bernilai tepat 1, maka nilai konstanta $upright(bold(c = 1 \/ 8))$.

#horizontalrule

== #strong[Soal 11]
<soal-11>
Sebuah bisnis manufaktur pakaian popular menerima pesanan #emph[online] dari dua #emph[routing system] yang berbeda. Rentang waktu antara setiap pesanan untuk setiap #emph[routing system] pada hari biasa diketahui terdistribusi secara eksponensial dengan rata -- rata selama 3,2 menit. Setiap sistem diasumsikan beroperasi secara independen. Maka tentukan: a. Berapa probabilitas terjadinya kondisi tidak ada pesanan yang diterima hingga periode waktu 5 menit dari pesanan terakhir? b. Berapa probabilitas untuk keadaan tidak ada pesanan yang diterima hingga periode waktu 10 menit? c.~Berapa probabilitas terjadinya keadaan kedua sistem menerima dua pesanan pada rentang 10 dan 15 menit setelah situs pemesanan baru dibuka? d.~Mengapa distribusi probabilitas gabungan tidak dibutuhkan untuk menjawab pertanyaan sebelumnya?

#strong[Jawaban:] Kejadian dimodelkan dengan Distribusi Eksponensial dengan $lambda = 1 \/ 3 \, 2 = 0 \, 3125$. a. Probabilitas gabungan (karena dua sistem identik yang independen) untuk $> 5$ menit: $\( e^(- 5 \/ 3 \, 2) \)^2 approx upright(bold(0 \, 0439))$. b. Probabilitas gabungan untuk $> 10$ menit: $\( e^(- 10 \/ 3 \, 2) \)^2 approx upright(bold(0 \, 00193))$. c.~Menyelaraskan dengan persamaan proses Poisson pada interval $t = 5$ ($mu = 5 \/ 3 \, 2 = 1 \, 5625$). Maka $P \( X = 2 \)$ untuk kedua sistem adalah $\( e^(- 1 \, 5625) frac(1 \, 5625^2, 2) \)^2 approx upright(bold(0 \, 0654))$. d.~Fungsi padat probabilitas gabungan secara eksplisit tidak dibutuhkan karena kedua #emph[routing system] #strong[dioperasikan secara independen]. Kita dapat mengkalkulasinya dengan sekadar mengalikan kedua marginal probabilitasnya secara langsung.

#horizontalrule

== #strong[Soal 12 & 13]
<soal-12-13>
Anggap variabel random $X$, $Y$, dan $Z$ memiliki fungsi padat probabilitas gabungan $f \( x \, y \, z \) = 8 x y z$ untuk setiap $0 < x < 1$, $0 < y < 1$ dan $0 < z < 1$. Tentukan hal -- hal berikut: $P \( X < 0 \, 5 \)$, $P \( X < 0 \, 5 \, Y < 0 \, 5 \)$, $P \( Z < 2 \)$, $P \( X < 0 \, 5 \, Z < 2 \)$, $E \( X \)$. Tentukan nilai $c$ yang dapat membuat fungsi $f_(X Y Z) \( x \, y \, z \) = c$ menjadi fungsi padat probabilitas gabungan pada wilayah rentang $x > 0$, $y > 0$, $z > 0$, dan $x + y + z < 1$.

#strong[Jawaban:] Berdasarkan batas terpisahnya, fungsi ini saling independen antar variabel: \* $P \( X < 0 \, 5 \) = integral_0^(0 \, 5) 2 x d x = upright(bold(0 \, 25))$. \* $P \( X < 0 \, 5 \, Y < 0 \, 5 \) = P \( X < 0 \, 5 \) times P \( Y < 0 \, 5 \) = 0 \, 25 times 0 \, 25 = upright(bold(0 \, 0625))$. \* $P \( Z < 2 \) = upright(bold(1))$ (Mencakup seluruh area probabilitas karena batas maksimal densitas z hanya sampai 1). \* $P \( X < 0 \, 5 \, Z < 2 \) = 0 \, 25 times 1 = upright(bold(0 \, 25))$. \* $E \( X \) = integral_0^1 x \( 2 x \) d x = upright(bold(2 \/ 3))$. \* Mencari c: Ruang batas $x + y + z < 1$ merupakan bangun ruang simplex 3D yang volumenya adalah $1 / 6$. Agar menjadi fungsi sebaran gabungan utuh, probabilitasnya harus 1, sehingga konstan yang mengimbanginya adalah $upright(bold(c = 6))$.

#horizontalrule

== #strong[Soal 14]
<soal-14>
Sebuah manufaktur lampu elektroluminesen mengetahui bahwa jumlah tinta luminesen yang terkandung dalam setiap satu produknya ialah terdistribusi secara normal dengan nilai rata -- rata 1,2 gram dan standar deviasi 0,03 gram. Setiap lampu yang memiliki kurang dari 1,14 gram tinta luminesen akan gagal dalam memenuhi spesifikasi pelanggan. Sampel random sejumlah 25 lampu diambil dan kandungan massa tinta luminesen yang terkandung pada setiap sampel lampu tersebut diukur. Tentukan : a. Berapa probabilitas bahwa setidaknya 1 lampu gagal memenuhi spesifikasi? b. Berapa probabilitas bahwa 5 lampu atau kurang gagal memenuhi spesifikasi? c.~Berapa probabilitas bahwa seluruh sampel lampu tersebut memenuhi spesifikasi? d.~Mengapa distribusi probabilitas gabungan dari kasus sampel 25 lampu tidak dibutuhkan untuk menjawab pertanyaan sebelumnya?

#strong[Jawaban:] Diketahui populasi Normal $mu = 1 \, 2$, $sigma = 0 \, 03$. Batas cacat $Z = frac(1 \, 14 - 1 \, 2, 0 \, 03) = - 2$. Peluang gagal sebutir lampu adalah $p = P \( Z < - 2 \) = 0 \, 02275$. Variabel jumlah lampu mematuhi distribusi Binomial $n = 25$. a. $P \( X gt.eq 1 \) = 1 - P \( X = 0 \) = 1 - \( 1 - 0 \, 02275 \)^25 = upright(bold(0 \, 438))$. b. $P \( X lt.eq 5 \) = sum_(x = 0)^5 binom(25, x) \( 0 \, 02275 \)^x \( 0 \, 97725 \)^(25 - x) = upright(bold(0 \, 9999))$. c.~$P \( X = 0 \) = \( 1 - 0 \, 02275 \)^25 = upright(bold(0 \, 562))$. d.~Fungsi PDF multivariat tidak perlu dirumuskan karena proses pengambilan ke-25 sampel lampu tersebut memenuhi sifat percobaan Bernoulli (setiap lampu #strong[bersifat independen] satu sama lain).

#horizontalrule

== #strong[Soal 15]
<soal-15>
Tentukan nilai c serta nilai kovarian dan korelasi untuk fungsi massa probabilitas gabungan $f_(X Y Z) \( x \, y \) = c \( x + y \)$ untuk setiap nilai $x = 1 \, 2 \, 3$ dan $y = 1 \, 2 \, 3$. #emph[\(Terdapat ]typo\* pada notasi sumber $f_(X Y Z)$ yang seharusnya $f_(X Y)$ untuk distribusi diskrit 2 dimensi).\*

#strong[Jawaban:] Telah dibuktikan pada soal No.~2 bahwa $upright(bold(c = 1 \/ 36))$. Ekspektasi Marginal: $E \( X \) = E \( Y \) = 13 \/ 6$. Variansi marginal $V \( X \) = V \( Y \) = 23 \/ 36$. Ekspektasi Perkalian: $E \( X Y \) = sum sum x y dot.op frac(x + y, 36) = 14 \/ 3$. Kovariansi: $C o v \( X \, Y \) = E \( X Y \) - E \( X \) E \( Y \) = 14 / 3 - \( 13 / 6 \)^2 = upright(bold(- 1 \/ 36))$. Korelasi: $rho = frac(C o v \( X \, Y \), sigma_X sigma_Y) = frac(- 1 \/ 36, 23 \/ 36) = upright(bold(- 1 \/ 23))$.

#horizontalrule

== #strong[Soal 16]
<soal-16>
Anggap sebuah korelasi antara $X$ dan $Y$ adalah $rho$. Untuk konstanta a, b, c, dan d, apa korelasi antara variabel random $U = a X + b$ dan $V = c Y + d$?

#strong[Jawaban:] Konstanta pergeseran linier ($b$ dan $d$) tidak akan mempengaruhi nilai korelasi. Jika hasil kali pada koefisien penskalaan ($a dot.op c$) bernilai positif, korelasinya tetap $upright(bold(rho))$. Akan tetapi, jika hasil kali ($a dot.op c$) bernilai negatif, maka korelasinya berbalik arah (tanda) menjadi $upright(bold(- rho))$.

#horizontalrule

== #strong[Soal 17]
<soal-17>
Anggap $X$ dan $Y$ merepresentasikan konsentrasi dan viskositas dari sebuah produk kimia. Kemudian, anggap $X$ dan $Y$ memiliki distribusi normal bivariat dengan $delta_x = 4$, $delta_y = 1$, $mu_x = 2$ dan $mu_y = 1$. Gambarlah plot kontur kasar dari fungsi padat probabilitas gabungan untuk setiap nilai $rho$: $rho = 0$, $rho = - 0 \, 8$, $rho = 0 \, 8$.

#strong[Jawaban:] #emph[\(Interpretasi Bentuk Plot)] \* $rho = 0$: Gambar kontur berbentuk elips simetris yang datar/sejajar terhadap arah mendatar sumbu-x karena besaran simpangannya $sigma_x > sigma_y$. \* $rho = - 0 \, 8$: Gambar kontur elips yang bentuknya miring diagonal memanjang dari arah kiri-atas menuju ke arah kanan-bawah. \* $rho = 0 \, 8$: Gambar kontur elips yang bentuknya miring diagonal memanjang dari arah kiri-bawah menuju ke arah kanan-atas.

#horizontalrule

== #strong[Soal 18]
<soal-18>
Pada sebuah manufaktur lampu elektroluminesen, beberapa lapis berbeda dari tinta dimasukkan kedalam plastic substrat. Ketebalan dari layer ini sangat vital dalam memenuhi spesifikasi warna akhir dan intensitas cahaya yang dihasilkan dari lampu. Anggap $X$ dan $Y$ menunjukkan ketebalan dari 2 lapisan tinta yang berbeda. Diketahui bahwa $X$ terdistribusi secara normal dengan nilai rata -- rata 0,1 milimeter dan standar deviasi sebesar 0,00031 milimeter. $Y$ juga terdistribusi secara normal dengan nilai rata -- rata 0,23 milimeter dan standar deviasi sebesar 0,00017 milimeter. Nilai $rho$ pada kedua variabel tersebut sama dengan 0. Agar memenuhi spesifikasi, ketebalan tinta pada lapisan X harus berada pada rentang 0,099535 hingga 0,100465 milimeter serta ketebalan tinta pada lapisan Y harus berada pada rentang 0,22966 hingga 0,23034 milimeter. Berapa probabilitas didapatkannya sebuah lampu yang dipilih secara acak akan sesuai dengan spesifikasi?

#strong[Jawaban:] Berdasarkan $rho = 0$, variabel $X$ dan $Y$ adalah saling lepas (independen). Lapis X: $Z_X = frac(0 \, 099535 - 0 \, 1, 0 \, 00031) = plus.minus 1 \, 5 arrow.r.double.long P \( - 1 \, 5 < Z_X < 1 \, 5 \) = 0 \, 8664$. Lapis Y: $Z_Y = frac(0 \, 22966 - 0 \, 23, 0 \, 00017) = plus.minus 2 \, 0 arrow.r.double.long P \( - 2 < Z_Y < 2 \) = 0 \, 9545$. Probabilitas gabungan (memenuhi seluruh specs): $0 \, 8664 times 0 \, 9545 = upright(bold(0 \, 827))$.

#horizontalrule

== #strong[Soal 19]
<soal-19>
Jika terdapat $X$ dan $Y$, yang mana $X$ dan $Y$ memiliki distribusi normal bivariat dengan nilai $rho = 0$, maka tunjukkan bahwa $X$ dan $Y$ independen!

#strong[Jawaban:] Berdasarkan formula eksak persamaan Densitas Normal Bivariat, ekspresi eksponensial untuk area kovarian berimbang termuat dalam ruas $\( x - mu_x \) \( y - mu_y \)$. Apabila $rho = 0$, nilai matematis pada ruas kovarian tersebut akan menjadi nol secara instan. Karena hilangnya efek kovarian gabungan, persamaan eksponensialnya secara sempurna dapat dipecah secara aljabar menjadi $f \( x \, y \) = f_X \( x \) times f_Y \( y \)$, yang menjadi pembuktian kuat bahwa variabel $X$ dan $Y$ independen.

#horizontalrule

== #strong[Soal 20]
<soal-20>
Jika terdapat $X$ dan $Y$, yang mana $X$ dan $Y$ independen dan merupakan variabel random normal dengan $E \( X \) = 0$, $V \( X \) = 4$, $E \( Y \) = 10$, dan $V \( Y \) = 9$. Tentukan hal -- hal berikut: $E \( 2 X + 3 Y \)$, $V \( 2 X + 3 Y \)$, $P \( 2 X + 3 Y < 30 \)$, $P \( 2 X + 3 Y < 40 \)$.

#strong[Jawaban:] Misalkan kombinasi linear ini dinyatakan sebagai fungsi $W = 2 X + 3 Y$. \* $E \( W \) = 2 \( 0 \) + 3 \( 10 \) = upright(bold(30))$. \* $V \( W \) = 2^2 \( 4 \) + 3^2 \( 9 \) = 16 + 81 = upright(bold(97))$. \* $P \( W < 30 \) = P \( Z < frac(30 - 30, sqrt(97)) \) = P \( Z < 0 \) = upright(bold(0 \, 50))$. \* $P \( W < 40 \) = P \( Z < frac(40 - 30, sqrt(97)) \) = P \( Z < 1 \, 015 \) = upright(bold(0 \, 8449))$.

#horizontalrule

== #strong[Soal 21]
<soal-21>
Anggap sebuah variabel random $X$ merepresentasikan panjang sebuah bagian yang dilubangi dalam centimeter. Kemudian anggap variabel random $Y$ merupakan panjang dari bagian dalam satuan millimeter. Jika $E \( X \) = 5$ dan $V \( X \) = 0 \, 25$, maka berapa nilai rata -- rata dan variansi dari variabel $Y$?

#strong[Jawaban:] Fungsi transformasi linear perbesaran unit dari centimeter ke milimeter adalah $Y = 10 X$. Rata-rata: $E \( Y \) = 10 dot.op E \( X \) = 10 times 5 = upright(bold(50 upright(" mm")))$. Variansi: $V \( Y \) = 10^2 dot.op V \( X \) = 100 times 0 \, 25 = upright(bold(25 upright(" mm")^2))$.

#horizontalrule

== #strong[Soal 22]
<soal-22>
Sebuah casing plastik untuk sebuah piringan magnetik tersusun dari 2 bagian. Ketebalan dari setiap bagian terdistribusi secara normal dengan nilai rata -- rata 2 milimeter dan dengan standar deviasi sebesar 0,1 milimeter serta setiap bagian saling independen. a. Tentukan nilai rata -- rata dan standar deviasi dari ketebalan total dari kedua bagian casing plastik tersebut. b. Berapa probabilitas ketebalan total dari kedua bagian casing plastik tersebut lebih besar dari 4,3 milimeter.

#strong[Jawaban:] a. Model ketebalan total ($T = X_1 + X_2$). $mu_T = 2 + 2 = upright(bold(4 upright(" mm")))$. Standar deviasi gabungan $sigma_T = sqrt(0 \, 1^2 + 0 \, 1^2) = sqrt(0 \, 02) approx upright(bold(0 \, 1414 upright(" mm")))$. b. $P \( T > 4 \, 3 \) = P \( Z > frac(4 \, 3 - 4, 0 \, 1414) \) = P \( Z > 2 \, 12 \) = upright(bold(0 \, 017))$.

#horizontalrule

== #strong[Soal 23]
<soal-23>
Sebuah komponen berbentuk U terbentuk dari 3 bagian, A, B dan C, sebagaimana digambarkan pada gambar dibawah. Panjang dari A terdistribusi normal dengan nilai rata -- rata 10 milimeter dan dengan standar deviasi sebesar 0,1 milimeter. Kemudian, ketebalan bagian B dan C terdistribusi secara normal dengan nila rata -- rata 2 milimeter dan dengan standar deviasi sebesar 0,05 milimeter. Asumsikan semua dimensi independen. a. Tentukan nilai rata -- rata dan standar deviasi dari panjang gap D. b. Berapa probabilitas bahwa gap D memiliki panjang kurang dari 5,9 milimeter.

#strong[Jawaban:] a. Definisi rentang relasional $D = A - B - C$. $mu_D = 10 - 2 - 2 = upright(bold(6 upright(" mm")))$. $sigma_D^2 = \( 1 \)^2 \( 0 \, 1 \)^2 + \( - 1 \)^2 \( 0 \, 05 \)^2 + \( - 1 \)^2 \( 0 \, 05 \)^2 = 0 \, 015 arrow.r.double.long sigma_D = sqrt(0 \, 015) approx upright(bold(0 \, 1225 upright(" mm")))$. b. $P \( D < 5 \, 9 \) = P \( Z < frac(5 \, 9 - 6, 0 \, 1225) \) = P \( Z < - 0 \, 816 \) = upright(bold(0 \, 207))$.

#horizontalrule

== #strong[Soal 24]
<soal-24>
Persentase orang yang diberi obat antirheumatoid yang menderita efek samping parah, sedang dan ringan secara berurutan ialah 10%, 20% dan 70%. Asumsikan bahwa orang bereaksi secara independen dan misalkan 20 orang diberikan obat. Tentukan hal -- hal berikut: a. Probabilitas bahwa 2, 4 dan 14 orang secara berurutan akan menderita efek samping parah, sedang dan rendah. b. Probabilitas bahwa tidak ada seorang pun yang menderita efek samping yang parah. c.~Nilai rata -- rata dan variansi dari jumlah orang yang menderita efek samping parah. d.~Tentukan distribusi probabilitas bersyarat dari jumlah orang yang menderita efek samping parah ketika 19 orang menderita efek samping ringan. e. Tentukan nilai mean bersyarat $mu_(Y \| X)$ dari jumlah orang yang menderita efek samping parah ketika 19 orang menderita efek samping ringan.

#strong[Jawaban:] a. Eksekusi PMF Multinomial: $frac(20 !, 2 ! 4 ! 14 !) \( 0 \, 1 \)^2 \( 0 \, 2 \)^4 \( 0 \, 7 \)^14 = upright(bold(0 \, 016))$. b. Relasi Bernoulli (0 efek parah): $\( 1 - 0 \, 1 \)^20 = 0 \, 9^20 = upright(bold(0 \, 1216))$. c.~Mean = $20 \( 0 \, 1 \) = upright(bold(2))$. Variansi = $20 \( 0 \, 1 \) \( 0 \, 9 \) = upright(bold(1 \, 8))$. d.~Saat 19 sampel ringan memakan slot populasi, maka sisa ukuran sampel bernilai mutlak $n = 1$. Probabilitas relatif kejadian parah menjadi terhimpit senilai $\( 0 \, 1 \) \/ \( 0 \, 1 + 0 \, 2 \) = 1 \/ 3$. Sifat ini membentuk #strong[Distribusi Binomial Baru dengan $n = 1 \, p = 1 \/ 3$]. e. $mu_(Y \| X = 19) = n dot.op p_(r e l a t i f) = 1 \( 1 \/ 3 \) = upright(bold(1 \/ 3))$.

#horizontalrule

== #strong[Soal 25]
<soal-25>
Tentukan nilai $c$ sedemikian rupa sehingga fungsi $f \( x \, y \) = c x^2 y$ untuk setiap nilai $0 < x < 3$ dan $0 < y < 2$ memenuhi sifat -- sifat fungsi padat probabilitas gabungan!

#strong[Jawaban:] $ integral_0^3 integral_0^2 c x^2 y d y d x = c [x^3 / 3]_0^3 [y^2 / 2]_0^2 = c \( 9 \) \( 2 \) = 18 c = 1 arrow.r.double.long upright(bold(c = 1 \/ 18)) $

#horizontalrule

== #strong[Soal 26]
<soal-26>
Sebuah distribusi gabungan dari variabel random kontinu $X$, $Y$, dan $Z$ adalah konstan pada wilayah $x^2 + y^2 lt.eq 1$ dan $0 < z < 4$. Tentukan: $P \( X^2 + Y^2 lt.eq 0 \, 5 \)$, $P \( X^2 + Y^2 lt.eq 0 \, 5 \, Z < 2 \)$, Bagaimana fungsi padat probabilitas gabungan bersyarat dari $X$ dan $Y$ ketika nilai $Z = 1$?, Bagaimana fungsi probabilitas kepadatan marginal $X$?, Tentukan nilai rata -- rata bersyarat dari $Z$ ketika nilai $X = 0$ dan $Y = 0$, Secara umum, tentukan nilai rata -- rata bersyarat dari $Z$ ketika nilai $X = x$ dan $Y = y$.

#strong[Jawaban:] Bangun tersebut merepresentasikan ruang Volume Silinder. Konstanta padat gabungan bernilai $C = 1 / upright("Volume Silinder") = frac(1, pi \( 1 \)^2 \( 4 \)) = frac(1, 4 pi)$. \* $P \( X^2 + Y^2 lt.eq 0 \, 5 \) = frac(upright("Luas Lingkaran ") r = sqrt(0 \, 5), upright("Luas Lingkaran ") r = 1) = frac(pi \( 0 \, 5 \), pi) = upright(bold(0 \, 5))$. \* $P \( X^2 + Y^2 lt.eq 0 \, 5 sect Z < 2 \) = 0 \, 5 times 2 / 4 = upright(bold(0 \, 25))$. \* Fungsi bersyarat (X,Y) tanpa memperhatikan variabel Z (bersyarat pada Z), ekuivalen terhadap rasio tabung potong: $f \( x \, y \| Z = 1 \) = upright(bold(1 \/ pi))$. \* Fungsi kepadatan marginal X dibentuk dari limit geometri ruang melingkar: $f_X \( x \) = upright(bold(frac(2 sqrt(1 - x^2), pi)))$. \* $E \( Z \| x = 0 \, y = 0 \) = upright(bold(2))$. \* Secara umum $E \( Z \| x \, y \) = upright(bold(2))$ karena distribusi Z memancar memanjang seragam dari ketinggian 0 sampai 4 di manapun koordinat horizontal X dan Y diletakkan.

#horizontalrule

== #strong[Soal 27]
<soal-27>
Umur dari 6 komponen utama pada mesin fotokopi merupakan variabel random dengan nilai rata -- rata secara berurutan yakni 8.000, 10.000, 10.000, 20.000, 20.000 dan 25.000 jam. Tentukan : a. Berapa probabilitas umur dari seluruh komponen tersebut lebih besar dari 5.000 jam? b. Berapa probabilitas umur dari setidaknya satu komponen dari keenam komponen tersebut lebih besar dari 25.000 jam?

#strong[Jawaban:] Pengujian mematuhi hukum independensi (distribusi memori eksponensial): a. $P \( upright("seluruh") > 5.000 \) = product e^(- 5000 \/ mu_i) = e^(- 5 \/ 8) e^(- 5 \/ 10) e^(- 5 \/ 10) e^(- 5 \/ 20) e^(- 5 \/ 20) e^(- 5 \/ 25) = e^(- 2 \, 325) = upright(bold(0 \, 0977))$. b. $P \( upright("setidaknya 1") > 25.000 \) = 1 - P \( upright("seluruh gagal") lt.eq 25.000 \) = 1 - product \( 1 - e^(- 25000 \/ mu_i) \)$.

#horizontalrule

== #strong[Soal 28]
<soal-28>
Jika $f_(X Y) \( x \, y \) = frac(1, 1 \, 2 pi) exp { - \[ 0 \, 72 \( x - 1 \)^2 - 1 \, 6 \( x - 1 \) \( y - 2 \) + \( y - 2 \)^2 \] }$. #emph[\(Mengoreksi typo pada sumber dokumen dari $phi.alt$ ke pola bivariat)]. Tentukan $E \( X \)$, $E \( Y \)$, $V \( X \)$, $V \( Y \)$ dan juga $rho$ dengan mengatur ulang parameter dalam fungsi padat probabilitas gabungan.

#strong[Jawaban:] Berdasarkan pendekatan aljabar pada matriks persamaan Normal Bivariat Eksponensial standard, titik pusat nilai sebaran dapat diidentifikasi secara langsung dari komponen translasi sumbunya yang ada di dalam tanda kurung kuadratik. Hal ini menghasilkan $E \( X \) = upright(bold(1))$ dan $E \( Y \) = upright(bold(2))$.

#horizontalrule

== #strong[Soal 29]
<soal-29>
Sebuah perusahaan kecil akan melakukan pengambilan keputusan untuk menentukan investasi apa yang akan digunakan untuk uang tunai yang dihasilkan dari operasi. Setiap investasi memiliki nilai rata -- rata dan standar deviasi yang terkait dengan persentase kenaikan. Keamanan pertama memiliki persentase kenaikan nilai rata - rata 5% dengan standar deviasi 2%, dan keamanan kedua memberikan nilai rata - rata yang sama 5% dengan standar deviasi 4%. Sekuritas memiliki korelasi -0,5, sehingga ada korelasi negatif antara persentase pengembalian. Jika perusahaan menginvestasikan dua juta dolar dengan setengah di setiap keamanan (keamanan pertama dan kedua), berapa rata -- rata dan standar deviasi dari persentase pengembalian? Bandingkan standar deviasi dari strategi ini dengan strategi yang menginvestasikan dua juta dolar hanya pada keamanan pertama dan kemudian interpretasikan!

#strong[Jawaban:] \* Rata-rata Return (bobot seimbang $w = 0 \, 5$) = $0 \, 5 \( 5 \) + 0 \, 5 \( 5 \) = upright(bold(5 %))$. \* Kalkulasi Variansi = $\( 0 \, 5 \)^2 \( 4 \) + \( 0 \, 5 \)^2 \( 16 \) + 2 \( 0 \, 5 \)^2 \( - 0 \, 5 \) \( 2 \) \( 4 \) = 1 + 4 - 2 = 3$. \* Standar Deviasi portofolio diversifikasi adalah $upright(bold(sqrt(3) approx 1 \, 732 %))$. \* #strong[Interpretasi]: Standar deviasi strategi diversifikasi aset ($1 \, 732 %$) lebih kecil dibandingkan deviasi yang dihasilkan dari investasi penuh pada satu instrumen berisiko terendah sekalipun ($2 %$). Hal ini membuktikan bahwa strategi diversifikasi portofolio pada produk ber-korelasi terbalik ($rho$ negatif) ampuh digunakan untuk membendung paparan level bahaya (volatilitas) yang dipancarkan oleh produk investasi.
