// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
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


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



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
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Random Variable untuk Pengambilan Keputusan],
  subtitle: [Probabilitas Statistika untuk Mahasiswa II-2111 Probabilitas dan Statistika],
  author: "Armein Z. R. Langi",
  date: "2026-03-30",
  lang: "id",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

= Random Variable untuk Pengambilan Keputusan
<random-variable-untuk-pengambilan-keputusan>
Probabilitas Statistika untuk Mahasiswa II-2111 Probabilitas dan Statistika

\
== Selamat Datang
<selamat-datang>
Buku ini ditulis untuk mendampingi mahasiswa #strong[II-2111 Probabilitas Statistika] memahami topik #strong[Random Variable] dengan cara yang lebih hidup, lebih aplikatif, dan lebih dekat dengan keputusan nyata.

Alih-alih memulai dari definisi yang terasa jauh, buku ini mengajak pembaca masuk dari pertanyaan yang lebih akrab:

- Bagaimana membuat keputusan ketika masa depan belum pasti?
- Bagaimana membandingkan dua pilihan yang sama-sama mungkin menguntungkan?
- Bagaimana memahami risiko, bukan hanya rata-rata?
- Bagaimana menggunakan Python untuk melihat pola, mencoba simulasi, dan memeriksa logika?

Buku ini dibangun dengan tiga semangat utama:

+ #strong[Decision-making oriented] \
  Probabilitas dipelajari sebagai alat untuk memilih dengan lebih bijaksana.

+ #strong[Python first for intuition] \
  Mahasiswa diajak mendapatkan #emph[quick wins] lebih dulu melalui simulasi, visualisasi, dan eksperimen.

+ #strong[Logic with meaning] \
  Definisi, rumus, dan teori tetap penting, tetapi selalu dihubungkan dengan makna dan konteks nyata.

== Cara Menggunakan Buku Ini
<cara-menggunakan-buku-ini>
Setiap bab dalam buku ini dirancang agar bisa dipelajari dengan pola:

+ #strong[Mulai dari konteks masalah]
+ #strong[Lihat quick win dengan Python]
+ #strong[Bangun intuisi]
+ #strong[Masuk ke model formal]
+ #strong[Jawab pertanyaan berbasis model]
+ #strong[Tarik implikasi keputusan]

Pola ini disebut pendekatan #strong[KMQA]:

- #strong[K] --- Konteks \
- #strong[M] --- Model \
- #strong[Q] --- Questions \
- #strong[A] --- Apply

== Struktur Buku
<struktur-buku>
Buku ini terdiri dari enam bab utama:

+ #strong[Pendahuluan Pengambilan Keputusan] \
  Mengaitkan probabilitas dengan keputusan nyata, risiko, dan Python.

+ #strong[Random Variable Umum] \
  Fondasi formal: range, diskrit vs kontinu, PMF, CDF, PDF, ekspektasi, dan varians.

+ #strong[Distribusi Random Variable Diskrit] \
  Uniform diskrit, Bernoulli, Binomial, Geometric, Poisson, dan distribusi empiris dari histogram.

+ #strong[Distribusi Random Variable Kontinu] \
  Uniform kontinu, Normal, Gamma, Exponential, Erlang, Weibull, Pareto, Chi-Square, dan hubungan antardistribusi.

+ #strong[Random Variable Multivariat dan Fungsi Random Variable] \
  Joint, marginal, conditional, covariance, correlation, independensi, dan transformasi peubah acak.

+ #strong[Penutup] \
  Ringkasan ide besar buku, checklist kompetensi, dan peneguhan bahwa probabilitas adalah cara berpikir di bawah ketidakpastian.

== Untuk Siapa Buku Ini
<untuk-siapa-buku-ini>
Buku ini terutama ditujukan untuk mahasiswa tingkat dua, khususnya yang: - ingin memahami probabilitas secara konseptual, - ingin melihat contoh nyata dan relevan, - ingin belajar Python sambil tetap berpikir, - dan ingin merasakan bahwa statistika bukan sekadar soal ujian, tetapi alat untuk hidup dan bekerja dengan lebih cerdas.

== Harapan
<harapan>
Semoga buku ini membantu Anda mengalami sesuatu yang penting: bahwa probabilitas bukanlah kumpulan simbol yang dingin, melainkan bahasa yang sangat berguna saat kita harus berpikir, memilih, dan bertindak di dunia yang tidak sepenuhnya pasti.

Silakan mulai dari #strong[Kata Pengantar], lalu masuk ke #strong[Bab 1].

= Kata Pengantar
<kata-pengantar>
Buku ini disusun untuk menemani para mahasiswa kuliah #strong[II-2111 Probabilitas Statistika] belajar, berpikir, dan bertumbuh. Mungkin muncul pertanyaan: di tengah begitu banyak buku, video, dan sumber belajar yang tersedia, mengapa masih perlu ada buku ini?

Jawaban paling jujurnya sederhana: karena belajar bukan hanya soal tersedianya materi, tetapi soal #strong[bagaimana hati dan pikiran kita digerakkan untuk mau memahami]. Buku ini lahir dari keinginan untuk membantu mahasiswa, khususnya generasi Z, agar tidak hanya “mengikuti kuliah” atau “mengerjakan soal”, tetapi sungguh-sungguh melihat bahwa probabilitas dan statistika adalah ilmu yang hidup, dekat, dan berguna untuk mengambil keputusan dalam dunia nyata.

Buku ini dibangun di atas dua keyakinan. Pertama, bahwa materi probabilitas dan statistika akan menjadi lebih bermakna bila dibingkai sebagai bagian dari #strong[pengambilan keputusan] atau inferensi. Kedua, bahwa pada zaman ini, pembelajaran akan lebih kuat bila didukung oleh #strong[Python] sebagai alat untuk mencoba, bereksperimen, mensimulasikan, dan memahami.

Pada dasarnya, hidup manusia penuh dengan keputusan. Setiap hari kita memilih, menimbang, memperkirakan, berharap, dan menghadapi konsekuensi. Dalam pengertian itu, pengambilan keputusan adalah salah satu wujud paling nyata dari kecerdasan manusia. Kita tidak disebut cerdas hanya karena tahu banyak hal, tetapi karena mampu menggunakan pengetahuan itu untuk memilih jalan yang lebih baik.

Menariknya, bentuk pengambilan keputusan tidak jauh berbeda dari menjawab soal ujian. Ada yang sederhana seperti #strong[true-false], ada yang berupa #strong[pilihan ganda], ada yang berbentuk isian singkat, jawaban satu kalimat, satu alinea, esai, bahkan disertasi. Semua itu pada dasarnya adalah latihan untuk memilih jawaban terbaik berdasarkan informasi yang tersedia. Bedanya, dalam kehidupan nyata, keputusan tidak hanya dinilai benar atau salah, tetapi juga membawa akibat yang sungguh kita rasakan.

Karena itu, untuk mengambil keputusan yang baik, kita memerlukan #strong[model]. Model membantu kita menyederhanakan kenyataan tanpa kehilangan makna yang penting. Dan model dibangun oleh #strong[variabel].

Kita mengenal variabel sebagai besaran yang nilainya dapat berubah. Misalnya, panjang dan lebar sebidang tanah kita nyatakan dengan $p$ dan $l$. Luas tanah kemudian dapat dimodelkan sebagai

$ L = p times l . $

Tentu luas tanah yang sesungguhnya bukanlah huruf $L$, melainkan suatu kenyataan fisik. Namun variabel itu menolong kita untuk memikirkan kenyataan tersebut secara lebih teratur. Dengan cara itulah manusia membangun ilmu: bukan dengan langsung menggenggam realitas sepenuhnya, tetapi dengan membuat model yang cukup baik untuk memahami dan bertindak.

Ada besaran yang ketika diukur hasilnya relatif tetap. Misalnya, luas meja atau panjang sebuah kabel. Tetapi ada juga besaran yang ketika diukur berulang kali hasilnya berubah-ubah. Misalnya, jumlah kendaraan yang lewat di gerbang tol antara pukul 09.00--10.00, jumlah pasien yang datang ke klinik dalam satu hari, atau skor pertandingan sepak bola. Besaran seperti inilah yang kita modelkan sebagai #strong[variabel acak] (#emph[random variable]).

Jika $X$ adalah variabel yang memodelkan jumlah kendaraan yang melewati suatu gerbang tol dalam rentang waktu tertentu, dan nilainya dapat berbeda dari satu hari ke hari berikutnya, maka $X$ adalah variabel acak. Variabel acak memiliki #strong[range], yaitu himpunan nilai-nilai yang mungkin diambilnya. Jika nilai-nilainya berupa bilangan diskrit, seperti 0, 1, 2, 3, dan seterusnya, maka kita menyebutnya variabel acak diskrit.

Dalam praktik, banyak pengukuran dilakukan secara diskrit karena kita menggunakan satuan tertentu. Namun secara teoritis, ada besaran yang lebih mudah dipahami sebagai kontinu. Waktu adalah contoh yang baik. Dalam praktik kita mengukurnya dalam tahun, bulan, hari, jam, menit, dan detik. Namun bila ketelitian itu terus diperhalus, kita dapat memandangnya sebagai kontinu. Pemilihan model diskrit atau kontinu bukan sekadar soal teknik, tetapi juga soal cara berpikir yang paling tepat untuk memahami suatu persoalan.

Hal penting yang perlu disadari adalah ini: sebelum suatu peristiwa terjadi, kita biasanya tidak tahu pasti berapa nilai aktual dari $X$. Yang kita miliki hanyalah pengetahuan tentang kemungkinan-kemungkinannya. Namun mengetahui range saja belum cukup untuk membuat keputusan. Kita membutuhkan sesuatu yang lebih kuat, yaitu ukuran yang mewakili kecenderungan nilai-nilai yang mungkin muncul. Di sinilah #strong[ekspektasi] menjadi sangat penting. Nilai $E \[ X \]$ dapat dipandang sebagai tebakan terbaik kita terhadap $X$ sebelum kenyataan terjadi.

Dari titik inilah probabilitas menjadi sangat berarti. Probabilitas menolong kita memberi bobot pada kemungkinan-kemungkinan. Dengan probabilitas, kita tidak hanya tahu apa saja yang mungkin terjadi, tetapi juga seberapa masuk akal masing-masing kemungkinan itu. Dari sana kita dapat menghitung ekspektasi, memahami risiko, dan akhirnya mengambil keputusan dengan dasar yang lebih bijaksana.

Bayangkan, misalnya, seseorang harus memilih apakah pesta pernikahannya akan diadakan #strong[indoor] atau #strong[outdoor]. Pilihan itu tampak sederhana. Namun begitu muncul pertanyaan, “Bagaimana kalau hujan?”, keputusan itu berubah. Tiba-tiba kita sadar bahwa memilih bukan hanya soal selera, tetapi juga soal menghadapi ketidakpastian. Dalam banyak hal, demikianlah hidup bekerja. Kita jarang mengambil keputusan dalam keadaan serba pasti. Justru karena ada ketidakpastian, kita perlu probabilitas dan statistika.

Maka, probabilitas dan statistika bukan sekadar kumpulan rumus. Keduanya adalah cara berpikir. Keduanya mengajarkan kita untuk rendah hati di hadapan ketidakpastian, tetapi juga berani bertindak dengan dasar yang lebih baik. Keduanya menolong kita menyadari bahwa meskipun masa depan tidak bisa diketahui sepenuhnya, masa depan tetap bisa dihadapi dengan pikiran yang jernih.

Lalu, mengapa #strong[Python]? Karena pada zaman ini, Python telah menjadi salah satu bahasa utama untuk berbicara dengan komputer. Dengan Python, kita bisa mencoba ide, membuat simulasi, memeriksa tebakan, dan melihat konsep bekerja secara nyata. Memang, sekarang kita juga dapat meminta AI memberikan jawaban. Namun bila kita hanya menerima jawaban akhir, sering kali kita kehilangan proses belajar yang sesungguhnya. Python memberi kita kesempatan untuk tetap berpikir, tetap bereksperimen, tetap bertanya, dan tetap bertumbuh---bahkan saat kita memanfaatkan AI.

Karena itu, buku ini berusaha memadukan #strong[konsep], #strong[intuisi], #strong[pengambilan keputusan], dan #strong[eksperimen komputasional]. Harapannya, mahasiswa tidak hanya mampu mengerjakan soal ujian, tetapi juga mampu melihat makna di balik soal itu: bahwa setiap konsep yang dipelajari sesungguhnya sedang melatih kita menjadi pribadi yang lebih cermat, lebih rasional, dan lebih bertanggung jawab dalam memilih.

Akhirnya, buku ini sendiri adalah hasil dari sebuah keputusan: keputusan untuk menyusun bahan ajar yang lebih dekat, lebih hidup, dan lebih bersahabat bagi para pembaca. Semoga keputusan ini adalah keputusan yang baik. Dan lebih daripada itu, semoga buku ini tidak hanya menambah pengetahuan, tetapi juga menumbuhkan keberanian untuk berpikir, mencoba, dan terus belajar.

#strong[Bandung, 31 Maret 2026] \
#strong[Armein Z. R. Langi]

= Bab 1. Pendahuluan Pengambilan Keputusan
<bab-1.-pendahuluan-pengambilan-keputusan>
== Tujuan Bab
<tujuan-bab>
Setelah mempelajari bab ini, mahasiswa diharapkan mampu:

+ melihat probabilitas dan statistika sebagai #strong[alat pengambilan keputusan],
+ memahami mengapa #strong[random variable] diperlukan untuk memodelkan dunia yang tidak pasti,
+ mengenali peran #strong[ekspektasi] dan #strong[varians] dalam membandingkan pilihan,
+ menggunakan #strong[Python] untuk mendapatkan #emph[quick wins] sebelum masuk ke logika formal,
+ menghubungkan konsep probabilitas dengan kasus nyata di bidang teknik, bisnis, dan layanan.

== Pembuka
<pembuka>
Banyak mahasiswa pertama kali bertemu probabilitas dan statistika sebagai kumpulan simbol, rumus, dan notasi yang terasa dingin. Padahal, di balik semua itu, probabilitas dan statistika sesungguhnya adalah bahasa untuk menjawab pertanyaan yang sangat manusiawi:

- Apa keputusan yang paling masuk akal bila masa depan belum pasti?
- Mana pilihan yang lebih aman?
- Mana yang lebih menguntungkan?
- Seberapa besar risiko yang harus kita tanggung?
- Kapan kita harus berhenti mengandalkan intuisi dan mulai menghitung?

Bab ini mengajak Anda masuk ke probabilitas bukan dari pintu definisi formal terlebih dahulu, tetapi dari pintu yang lebih akrab: #strong[pengambilan keputusan].

== 1.1 Dari Pilihan ke Model
<dari-pilihan-ke-model>
Setiap hari manusia membuat keputusan. Sebagian kecil: memilih rute ke kampus, memilih tempat makan siang, memilih waktu belajar. Sebagian lain lebih besar: memilih investasi, menentukan kebijakan produksi, menetapkan garansi, menambah jumlah dokter, atau menentukan batas aman komponen listrik.

Masalahnya, keputusan hampir selalu dibuat #strong[sebelum] kita tahu apa yang akan terjadi. Masa depan belum datang, data belum lengkap, keadaan tidak sepenuhnya pasti. Karena itu, kita membutuhkan #strong[model].

Model membantu kita menyederhanakan kenyataan agar bisa dipikirkan, dihitung, dan diputuskan. Salah satu model paling penting dalam probabilitas adalah #strong[random variable]. Dengan random variable, kejadian yang semula acak dipetakan menjadi angka. Begitu dunia acak berhasil dipetakan ke bilangan, kita bisa mulai menghitung: - peluang, - rata-rata jangka panjang, - seberapa liar penyimpangannya, - dan konsekuensi keputusan.

== 1.2 Quick Win: Melihat Mengapa Rata-Rata Saja Tidak Cukup
<quick-win-melihat-mengapa-rata-rata-saja-tidak-cukup>
Mari mulai dari contoh yang sangat sederhana. Misalkan Anda harus memilih satu dari dua opsi investasi:

- #strong[A]: stabil, keuntungan kecil tetapi konsisten
- #strong[B]: bisa sangat menguntungkan, tetapi bisa juga sangat buruk

Secara kasatmata, dua opsi bisa saja memiliki rata-rata hasil yang sama. Tetapi apakah itu berarti keduanya sama baik?

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("42");#NormalTok(")");],
[],
[#CommentTok("## Dua investasi dengan mean hampir sama, tetapi variasi berbeda");],
[#NormalTok("A ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#DecValTok("10");#NormalTok(", scale");#OperatorTok("=");#DecValTok("2");#NormalTok(", size");#OperatorTok("=");#DecValTok("10000");#NormalTok(")");],
[#NormalTok("B ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#DecValTok("10");#NormalTok(", scale");#OperatorTok("=");#DecValTok("12");#NormalTok(", size");#OperatorTok("=");#DecValTok("10000");#NormalTok(")");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean A =\"");#NormalTok(", A.mean())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Var A  =\"");#NormalTok(", A.var())");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean B =\"");#NormalTok(", B.mean())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Var B  =\"");#NormalTok(", B.var())");],));
#block[
#Skylighting(([#NormalTok("Mean A = 9.979500249171975");],
[#NormalTok("Var A  = 4.050444191840732");],
[#NormalTok("Mean B = 10.24422094568761");],
[#NormalTok("Var B  = 144.83317214885628");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("9");#NormalTok(", ");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(A, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Investasi A\"");#NormalTok(")");],
[#NormalTok("plt.hist(B, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Investasi B\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Return\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Dua investasi dengan mean hampir sama, variance sangat berbeda\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("01-pendahuluan-pengambilan-keputusan_files/figure-typst/cell-3-output-1.svg"))

Dari hasil ini, kita segera mendapat #emph[quick win]:

- #strong[mean] memberi gambaran hasil rata-rata,
- #strong[variance] memberi gambaran seberapa liar hasil itu,
- keputusan yang matang tidak cukup melihat rata-rata, tetapi juga perlu melihat #strong[risiko].

Di sinilah probabilitas dan random variable mulai terasa hidup. Kita tidak sedang belajar rumus demi rumus. Kita sedang belajar cara membandingkan pilihan secara bertanggung jawab.

== 1.3 Pola Umum Pengambilan Keputusan
<pola-umum-pengambilan-keputusan>
Dalam buku ini, kita akan sering memakai pola berikut:

=== K --- Konteks
<k-konteks>
Apa situasi nyatanya? Siapa pengambil keputusan? Apa kebutuhan dan risikonya?

=== M --- Model
<m-model>
Apa random variable yang relevan? Apa asumsi masuk akalnya? Apa parameter pentingnya?

=== Q --- Questions
<q-questions>
Apa pertanyaan yang benar-benar ingin dijawab? Peluang? Rata-rata? Risiko bangkrut? Peluang cacat? Jumlah pelanggan? Waktu tunggu?

=== A --- Apply
<a-apply>
Gunakan Python, simulasi, visualisasi, dan teori probabilitas untuk menjawab pertanyaan dan menarik implikasi keputusan.

Pola ini akan kita sebut sebagai pendekatan #strong[KMQA]: #strong[Konteks → Model → Questions → Apply].

== 1.4 Random Variable sebagai Bahasa Angka untuk Dunia Acak
<random-variable-sebagai-bahasa-angka-untuk-dunia-acak>
Misalkan sebuah gerbang tol mencatat jumlah kendaraan yang lewat antara pukul 09.00--10.00. Besaran itu tidak pasti. Setiap hari nilainya bisa berbeda. Kita dapat menyatakan besaran ini sebagai sebuah random variable:

$ X = upright("jumlah kendaraan yang melewati gerbang tol antara pukul 09.00–10.00") $

Dengan begitu, kejadian nyata yang berubah-ubah kita petakan menjadi bilangan. Begitu sudah menjadi bilangan, kita bisa bertanya: - berapa nilai yang mungkin? - berapa peluang setiap nilai? - berapa rata-ratanya? - seberapa besar variasinya?

Itulah inti random variable.

== 1.5 Kasus 1 --- Ekspektasi dan Varians dalam Pilihan Investasi
<kasus-1-ekspektasi-dan-varians-dalam-pilihan-investasi>
=== K --- Konteks
<k-konteks-1>
Seorang mahasiswa mendapat dua opsi investasi kecil untuk dana tabungannya:

- Investasi A: hasil tidak terlalu tinggi, tetapi relatif stabil.
- Investasi B: kadang sangat tinggi, kadang turun tajam.

Ia bertanya: #emph[kalau saya ingin mengambil keputusan yang lebih dewasa, ukuran apa yang harus saya lihat?]

=== M --- Model
<m-model-1>
Misalkan: - $X_A$ = return investasi A - $X_B$ = return investasi B

Masing-masing adalah random variable. Dua ukuran dasar yang penting adalah:

$ E \[ X \] = upright("ekspektasi") $

dan

$ upright(V a r) \( X \) = E \[ \( X - E \[ X \] \)^2 \] $

Ekspektasi memberi gambaran hasil rata-rata jangka panjang. Varians memberi ukuran seberapa jauh hasil itu bisa menyimpang.

=== Q --- Questions
<q-questions-1>
+ Mana investasi dengan rata-rata hasil lebih baik?
+ Mana investasi dengan risiko lebih besar?
+ Bila dua investasi punya rata-rata hampir sama, apakah variance dapat mengubah keputusan?

=== A --- Apply
<a-apply-1>
#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("7");#NormalTok(")");],
[],
[#NormalTok("XA ");#OperatorTok("=");#NormalTok(" rng.choice([");#DecValTok("8");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("12");#NormalTok("], size");#OperatorTok("=");#DecValTok("100000");#NormalTok(", p");#OperatorTok("=");#NormalTok("[");#FloatTok("0.25");#NormalTok(", ");#FloatTok("0.50");#NormalTok(", ");#FloatTok("0.25");#NormalTok("])");],
[#NormalTok("XB ");#OperatorTok("=");#NormalTok(" rng.choice([");#OperatorTok("-");#DecValTok("15");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("20");#NormalTok(", ");#DecValTok("30");#NormalTok("], size");#OperatorTok("=");#DecValTok("100000");#NormalTok(", p");#OperatorTok("=");#NormalTok("[");#FloatTok("0.10");#NormalTok(", ");#FloatTok("0.20");#NormalTok(", ");#FloatTok("0.30");#NormalTok(", ");#FloatTok("0.25");#NormalTok(", ");#FloatTok("0.15");#NormalTok("])");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"E[XA] ~\"");#NormalTok(", XA.mean(), ");#StringTok("\" Var[XA] ~\"");#NormalTok(", XA.var())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"E[XB] ~\"");#NormalTok(", XB.mean(), ");#StringTok("\" Var[XB] ~\"");#NormalTok(", XB.var())");],));
#block[
#Skylighting(([#NormalTok("E[XA] ~ 10.0018  Var[XA] ~ 2.0022367599999997");],
[#NormalTok("E[XB] ~ 12.0198  Var[XB] ~ 147.42240796");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("9");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(XA, bins");#OperatorTok("=");#NormalTok("np.arange(XA.");#BuiltInTok("min");#NormalTok("()");#OperatorTok("-");#FloatTok("0.5");#NormalTok(", XA.");#BuiltInTok("max");#NormalTok("()");#OperatorTok("+");#FloatTok("1.5");#NormalTok("), alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", label");#OperatorTok("=");#StringTok("\"XA\"");#NormalTok(")");],
[#NormalTok("plt.hist(XB, bins");#OperatorTok("=");#NormalTok("np.arange(XB.");#BuiltInTok("min");#NormalTok("()");#OperatorTok("-");#FloatTok("0.5");#NormalTok(", XB.");#BuiltInTok("max");#NormalTok("()");#OperatorTok("+");#FloatTok("1.5");#NormalTok("), alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", label");#OperatorTok("=");#StringTok("\"XB\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Return\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Probability / Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Distribusi return dua investasi\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("01-pendahuluan-pengambilan-keputusan_files/figure-typst/cell-5-output-1.svg"))

==== Interpretasi
<interpretasi>
Investasi dengan ekspektasi lebih tinggi memang tampak menarik. Tetapi bila variance-nya juga jauh lebih besar, maka keputusan tidak sesederhana “pilih yang rata-ratanya terbesar”. Dalam dunia teknik, sains data, dan bisnis, keputusan hampir selalu menimbang #strong[nilai harapan] dan #strong[ketidakpastian] sekaligus.

==== Poin inti
<poin-inti>
- Ekspektasi = pusat distribusi
- Varians = ukuran penyebaran
- Dua pilihan dengan mean sama belum tentu sama baik
- Probabilitas membantu kita memilih secara lebih sadar, bukan sekadar “feeling”

=== Latihan singkat
<latihan-singkat>
+ Buat dua investasi lain yang punya mean hampir sama tetapi variance berbeda.
+ Simulasikan 10.000 kali dan bandingkan histogramnya.
+ Investasi mana yang akan Anda pilih jika Anda tidak tahan melihat hasil negatif besar?

== 1.6 Kasus 2 --- Produk Cacat dan Quality Control
<kasus-2-produk-cacat-dan-quality-control>
=== K --- Konteks
<k-konteks-2>
Sebuah pabrik mengklaim bahwa peluang sebuah produk cacat hanya 1%. Tim quality control mengambil sampel 100 unit. Mereka ingin tahu peluang menemukan tepat 2 produk cacat. Keputusan yang akan diambil: apakah produksi lanjut seperti biasa, perlu inspeksi tambahan, atau bahkan perlu dihentikan sementara?

=== M --- Model
<m-model-2>
Jika: - setiap unit independen, - tiap unit punya peluang cacat $p = 0.01$, - jumlah sampel $n = 100$,

maka banyaknya produk cacat $X$ dapat dimodelkan sebagai:

$ X tilde.op upright(B i n o m i a l) \( n = 100 \, p = 0.01 \) $

Untuk kejadian langka, distribusi Poisson juga sering menjadi pendekatan:

$ X approx upright(P o i s s o n) \( lambda = n p = 1 \) $

=== Q --- Questions
<q-questions-2>
+ Berapa peluang tepat 2 cacat?
+ Seberapa baik Poisson mendekati Binomial pada kasus ini?
+ Jika ditemukan terlalu banyak cacat, kapan QC harus curiga?

=== A --- Apply
<a-apply-2>
#block[
#Skylighting(([#ImportTok("from");#NormalTok(" math ");#ImportTok("import");#NormalTok(" comb, exp, factorial");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.01");],
[#NormalTok("k ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");],
[#NormalTok("lam ");#OperatorTok("=");#NormalTok(" n ");#OperatorTok("*");#NormalTok(" p");],
[],
[#NormalTok("binom_p ");#OperatorTok("=");#NormalTok(" comb(n, k) ");#OperatorTok("*");#NormalTok(" (p");#OperatorTok("**");#NormalTok("k) ");#OperatorTok("*");#NormalTok(" ((");#DecValTok("1");#OperatorTok("-");#NormalTok("p)");#OperatorTok("**");#NormalTok("(n");#OperatorTok("-");#NormalTok("k))");],
[#NormalTok("pois_p ");#OperatorTok("=");#NormalTok(" exp(");#OperatorTok("-");#NormalTok("lam) ");#OperatorTok("*");#NormalTok(" (lam");#OperatorTok("**");#NormalTok("k) ");#OperatorTok("/");#NormalTok(" factorial(k)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=2) Binomial =\"");#NormalTok(", binom_p)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=2) Poisson  =\"");#NormalTok(", pois_p)");],));
#block[
#Skylighting(([#NormalTok("P(X=2) Binomial = 0.18486481882486325");],
[#NormalTok("P(X=2) Poisson  = 0.18393972058572117");],));
]
]
#Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" binom, poisson");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", ");#DecValTok("8");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("9");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.stem(x, binom.pmf(x, n, p), linefmt");#OperatorTok("=");#StringTok("'C0-'");#NormalTok(", markerfmt");#OperatorTok("=");#StringTok("'C0o'");#NormalTok(", basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Binomial\"");#NormalTok(")");],
[#NormalTok("plt.stem(x");#OperatorTok("+");#FloatTok("0.1");#NormalTok(", poisson.pmf(x, lam), linefmt");#OperatorTok("=");#StringTok("'C1-'");#NormalTok(", markerfmt");#OperatorTok("=");#StringTok("'C1s'");#NormalTok(", basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Poisson approx\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Jumlah produk cacat\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Peluang\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Binomial vs Poisson untuk produk cacat\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("01-pendahuluan-pengambilan-keputusan_files/figure-typst/cell-7-output-1.svg"))

==== Interpretasi
<interpretasi-1>
Kasus ini penting karena memperkenalkan dua hal sekaligus: 1. random variable diskrit untuk menghitung banyak kejadian, 2. pentingnya memilih model yang tepat.

Engineer yang baik bukan yang hafal rumus paling banyak, tetapi yang tahu model mana yang masuk akal untuk suatu konteks.

=== Latihan singkat
<latihan-singkat-1>
+ Hitung peluang tepat 0, 1, 2, dan 3 cacat.
+ Bandingkan hasil Binomial dan Poisson.
+ Jika pabrik menemukan 6 produk cacat dari 100, apakah itu masih terasa wajar?

== 1.7 Kasus 3 --- Garansi Produk dan Risiko Klaim
<kasus-3-garansi-produk-dan-risiko-klaim>
=== K --- Konteks
<k-konteks-3>
Sebuah perusahaan lampu ingin menetapkan masa garansi. Umur lampu bersifat acak. Jika masa garansi terlalu pendek, pelanggan kecewa. Jika terlalu panjang, biaya klaim bisa membengkak. Keputusan harus menyeimbangkan daya saing produk dan risiko kerugian.

=== M --- Model
<m-model-3>
Misalkan umur lampu $X$ dinyatakan dalam jam. Untuk contoh awal, anggap:

$ X tilde.op cal(N) \( 900 \, 50^2 \) $

Artinya: - rata-rata umur = 900 jam - simpangan baku = 50 jam

Yang ingin dihitung misalnya: $ P \( X < T \) $ yaitu peluang lampu rusak sebelum waktu garansi $T$.

=== Q --- Questions
<q-questions-3>
+ Berapa peluang rusak sebelum 800 jam?
+ Bagaimana jika garansi 850 jam? 900 jam?
+ Mana kebijakan yang lebih aman bagi perusahaan?

=== A --- Apply
<a-apply-3>
#block[
#Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" norm");],
[],
[#NormalTok("mu ");#OperatorTok("=");#NormalTok(" ");#DecValTok("900");],
[#NormalTok("sigma ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");],
[],
[#ControlFlowTok("for");#NormalTok(" T ");#KeywordTok("in");#NormalTok(" [");#DecValTok("800");#NormalTok(", ");#DecValTok("850");#NormalTok(", ");#DecValTok("900");#NormalTok("]:");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P(X < ");#SpecialCharTok("{");#NormalTok("T");#SpecialCharTok("}");#SpecialStringTok(") =\"");#NormalTok(", norm.cdf(T, loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma))");],));
#block[
#Skylighting(([#NormalTok("P(X < 800) = 0.0227501319481792");],
[#NormalTok("P(X < 850) = 0.15865525393145707");],
[#NormalTok("P(X < 900) = 0.5");],));
]
]
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("700");#NormalTok(", ");#DecValTok("1100");#NormalTok(", ");#DecValTok("400");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" norm.pdf(x, loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("9");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf, label");#OperatorTok("=");#StringTok("\"PDF umur lampu\"");#NormalTok(")");],
[#ControlFlowTok("for");#NormalTok(" T ");#KeywordTok("in");#NormalTok(" [");#DecValTok("800");#NormalTok(", ");#DecValTok("850");#NormalTok(", ");#DecValTok("900");#NormalTok("]:");],
[#NormalTok("    plt.axvline(T, linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", label");#OperatorTok("=");#SpecialStringTok("f\"T=");#SpecialCharTok("{");#NormalTok("T");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Jam hidup\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Distribusi umur lampu dan pilihan masa garansi\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("01-pendahuluan-pengambilan-keputusan_files/figure-typst/cell-9-output-1.svg"))

==== Interpretasi
<interpretasi-2>
Statistika di sini bukan sekadar menjelaskan data. Ia menjadi alat desain keputusan. Dengan probabilitas, perusahaan dapat memperkirakan biaya klaim sebelum kebijakan garansi benar-benar diterapkan.

=== Latihan singkat
<latihan-singkat-2>
+ Hitung peluang rusak sebelum 875 jam.
+ Jika target klaim maksimum 10%, berapa garansi maksimum yang bisa diberikan?
+ Bagaimana jika simpangan baku membesar menjadi 80 jam?

== 1.8 Kasus 4 --- Fungsi Random Variable dan Keamanan Sistem
<kasus-4-fungsi-random-variable-dan-keamanan-sistem>
=== K --- Konteks
<k-konteks-4>
Dalam sistem kelistrikan sederhana, daya dapat dinyatakan sebagai:

$ P = I^2 R $

Jika arus $I$ memiliki variasi kecil, daya $P$ juga akan ikut acak. Tetapi karena hubungan ini kuadratik, perubahan kecil pada arus bisa membesar pada daya. Untuk sistem teknik, pertanyaan pentingnya adalah: #emph[seberapa sering daya melewati ambang aman?]

=== M --- Model
<m-model-4>
Misalkan: - $I$ random, - $R$ konstan, - $P = g \( I \) = I^2 R$

Berarti $P$ adalah fungsi dari random variable lain. Karakter distribusi $P$ bisa sangat berbeda dari distribusi $I$.

=== Q --- Questions
<q-questions-4>
+ Jika $I$ berdistribusi normal, seperti apa distribusi $P$?
+ Berapa peluang $P$ melampaui batas aman tertentu?
+ Mengapa transformasi nonlinear penting dalam desain?

=== A --- Apply
<a-apply-4>
#block[
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("123");#NormalTok(")");],
[#NormalTok("I ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#DecValTok("10");#NormalTok(", scale");#OperatorTok("=");#FloatTok("0.8");#NormalTok(", size");#OperatorTok("=");#DecValTok("100000");#NormalTok(")");],
[#NormalTok("R ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[#NormalTok("P ");#OperatorTok("=");#NormalTok(" (I");#OperatorTok("**");#DecValTok("2");#NormalTok(") ");#OperatorTok("*");#NormalTok(" R");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean(I) =\"");#NormalTok(", I.mean(), ");#StringTok("\"Var(I) =\"");#NormalTok(", I.var())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean(P) =\"");#NormalTok(", P.mean(), ");#StringTok("\"Var(P) =\"");#NormalTok(", P.var())");],));
#block[
#Skylighting(([#NormalTok("Mean(I) = 10.001059538027341 Var(I) = 0.6397573277010377");],
[#NormalTok("Mean(P) = 503.3047460543435 Var(P) = 6420.356765767546");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("9");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(I, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Arus I\"");#NormalTok(")");],
[#NormalTok("plt.hist(P, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Daya P = I^2 R\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Nilai\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Distribusi input vs distribusi output setelah transformasi nonlinear\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("01-pendahuluan-pengambilan-keputusan_files/figure-typst/cell-11-output-1.svg"))

==== Interpretasi
<interpretasi-3>
Kasus ini menunjukkan gagasan penting: - random variable tidak selalu berdiri sendiri, - fungsi dari random variable dapat mengubah bentuk distribusi, - keputusan teknik sering bergantung pada distribusi output, bukan sekadar distribusi input.

=== Latihan singkat
<latihan-singkat-3>
+ Hitung peluang $P > 600$.
+ Ubah simpangan baku arus menjadi 1.5 dan lihat perubahan distribusi daya.
+ Mengapa fungsi kuadrat lebih “berbahaya” daripada fungsi linear dalam konteks batas aman?

== 1.9 Kasus 5 --- Varians, Profit, dan Risiko Bangkrut
<kasus-5-varians-profit-dan-risiko-bangkrut>
=== K --- Konteks
<k-konteks-5>
Sebuah perusahaan memproduksi 1000 unit per hari. Biaya produksi tiap produk adalah \$100. Produk dijual dengan margin 10% per unit yang laku. Penjualan per hari bersifat acak dengan rata-rata 1000 unit. Profit harian ditambahkan ke saldo modal. Bila saldo modal negatif, perusahaan bangkrut.

Pertanyaannya: - kalau rata-rata profit positif, apakah perusahaan pasti aman? - apakah variance besar pada penjualan bisa tetap membunuh perusahaan?

=== M --- Model
<m-model-5>
- biaya per produk = \$100
- produksi per hari = 1000
- harga jual per produk = \$110
- biaya produksi harian = \$100,000

Jika penjualan harian $X_t$, maka profit harian:

$ Pi_t = 110 X_t - 100000 $

Saldo modal diperbarui setiap hari:

$ M_t = M_(t - 1) + Pi_t $

Jika $M_t < 0$, perusahaan bangkrut.

=== Q --- Questions
<q-questions-5>
+ Jika rata-rata penjualan 1000, apakah expected profit harian positif?
+ Bagaimana pengaruh variance penjualan terhadap risiko bangkrut?
+ Bagaimana peran modal awal 1x, 2x, 3x biaya produksi harian?

=== A --- Apply
<a-apply-5>
#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("123");#NormalTok(")");],
[],
[#NormalTok("cost_per_product ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("production ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1000");],
[#NormalTok("selling_price ");#OperatorTok("=");#NormalTok(" ");#DecValTok("110");],
[#NormalTok("daily_cost ");#OperatorTok("=");#NormalTok(" cost_per_product ");#OperatorTok("*");#NormalTok(" production");],
[#NormalTok("mean_sales ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1000");],
[],
[#KeywordTok("def");#NormalTok(" simulate_company(days");#OperatorTok("=");#DecValTok("365");#NormalTok(", initial_capital");#OperatorTok("=");#DecValTok("100000");#NormalTok(", sales_std");#OperatorTok("=");#DecValTok("250");#NormalTok(", n_sims");#OperatorTok("=");#DecValTok("2000");#NormalTok("):");],
[#NormalTok("    bankrupt ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    final_capitals ");#OperatorTok("=");#NormalTok(" []");],
[],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(n_sims):");],
[#NormalTok("        sales ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#NormalTok("mean_sales, scale");#OperatorTok("=");#NormalTok("sales_std, size");#OperatorTok("=");#NormalTok("days)");],
[#NormalTok("        sales ");#OperatorTok("=");#NormalTok(" np.maximum(");#DecValTok("0");#NormalTok(", np.");#BuiltInTok("round");#NormalTok("(sales))");],
[#NormalTok("        profit ");#OperatorTok("=");#NormalTok(" selling_price ");#OperatorTok("*");#NormalTok(" sales ");#OperatorTok("-");#NormalTok(" daily_cost");],
[#NormalTok("        capital ");#OperatorTok("=");#NormalTok(" initial_capital ");#OperatorTok("+");#NormalTok(" np.cumsum(profit)");],
[],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" np.");#BuiltInTok("any");#NormalTok("(capital ");#OperatorTok("<");#NormalTok(" ");#DecValTok("0");#NormalTok("):");],
[#NormalTok("            bankrupt ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("        final_capitals.append(capital[");#OperatorTok("-");#DecValTok("1");#NormalTok("])");],
[],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" np.array(final_capitals), bankrupt ");#OperatorTok("/");#NormalTok(" n_sims");],));
]
#block[
#Skylighting(([#NormalTok("capital_levels ");#OperatorTok("=");#NormalTok(" [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok("]");],
[#NormalTok("sales_stds ");#OperatorTok("=");#NormalTok(" [");#DecValTok("50");#NormalTok(", ");#DecValTok("150");#NormalTok(", ");#DecValTok("300");#NormalTok(", ");#DecValTok("500");#NormalTok("]");],
[],
[#NormalTok("results ");#OperatorTok("=");#NormalTok(" {}");],
[],
[#ControlFlowTok("for");#NormalTok(" c ");#KeywordTok("in");#NormalTok(" capital_levels:");],
[#NormalTok("    init_cap ");#OperatorTok("=");#NormalTok(" c ");#OperatorTok("*");#NormalTok(" daily_cost");],
[#NormalTok("    results[c] ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" s ");#KeywordTok("in");#NormalTok(" sales_stds:");],
[#NormalTok("        finals, p_bankrupt ");#OperatorTok("=");#NormalTok(" simulate_company(initial_capital");#OperatorTok("=");#NormalTok("init_cap, sales_std");#OperatorTok("=");#NormalTok("s)");],
[#NormalTok("        results[c].append((s, finals.mean(), p_bankrupt))");],
[],
[#ControlFlowTok("for");#NormalTok(" c ");#KeywordTok("in");#NormalTok(" capital_levels:");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"");#CharTok("\\n");#SpecialStringTok("Modal awal = ");#SpecialCharTok("{");#NormalTok("c");#SpecialCharTok("}");#SpecialStringTok(" x biaya harian\"");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" s, mean_final, p_bankrupt ");#KeywordTok("in");#NormalTok(" results[c]:");],
[#NormalTok("        ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"std sales=");#SpecialCharTok("{");#NormalTok("s");#SpecialCharTok(":>3}");#SpecialStringTok(" | mean final capital=");#SpecialCharTok("{");#NormalTok("mean_final");#SpecialCharTok(":,.0f}");#SpecialStringTok(" | P(bankrupt)=");#SpecialCharTok("{");#NormalTok("p_bankrupt");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("Modal awal = 1 x biaya harian");],
[#NormalTok("std sales= 50 | mean final capital=3,751,041 | P(bankrupt)=0.000");],
[#NormalTok("std sales=150 | mean final capital=3,755,095 | P(bankrupt)=0.001");],
[#NormalTok("std sales=300 | mean final capital=3,780,991 | P(bankrupt)=0.105");],
[#NormalTok("std sales=500 | mean final capital=3,903,849 | P(bankrupt)=0.377");],
[],
[#NormalTok("Modal awal = 2 x biaya harian");],
[#NormalTok("std sales= 50 | mean final capital=3,847,908 | P(bankrupt)=0.000");],
[#NormalTok("std sales=150 | mean final capital=3,857,446 | P(bankrupt)=0.000");],
[#NormalTok("std sales=300 | mean final capital=3,849,650 | P(bankrupt)=0.022");],
[#NormalTok("std sales=500 | mean final capital=4,004,548 | P(bankrupt)=0.192");],
[],
[#NormalTok("Modal awal = 3 x biaya harian");],
[#NormalTok("std sales= 50 | mean final capital=3,950,421 | P(bankrupt)=0.000");],
[#NormalTok("std sales=150 | mean final capital=3,955,070 | P(bankrupt)=0.000");],
[#NormalTok("std sales=300 | mean final capital=3,950,022 | P(bankrupt)=0.002");],
[#NormalTok("std sales=500 | mean final capital=4,118,620 | P(bankrupt)=0.087");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("9");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#ControlFlowTok("for");#NormalTok(" c ");#KeywordTok("in");#NormalTok(" capital_levels:");],
[#NormalTok("    xs ");#OperatorTok("=");#NormalTok(" [r[");#DecValTok("0");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" r ");#KeywordTok("in");#NormalTok(" results[c]]");],
[#NormalTok("    ys ");#OperatorTok("=");#NormalTok(" [r[");#DecValTok("2");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" r ");#KeywordTok("in");#NormalTok(" results[c]]");],
[#NormalTok("    plt.plot(xs, ys, marker");#OperatorTok("=");#StringTok("'o'");#NormalTok(", label");#OperatorTok("=");#SpecialStringTok("f\"Modal awal ");#SpecialCharTok("{");#NormalTok("c");#SpecialCharTok("}");#SpecialStringTok("x biaya harian\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Std penjualan harian\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Peluang bangkrut\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Variance besar dapat mematikan perusahaan walau expected profit positif\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("01-pendahuluan-pengambilan-keputusan_files/figure-typst/cell-14-output-1.svg"))

==== Interpretasi
<interpretasi-4>
Ini adalah salah satu pelajaran paling penting dalam probabilitas untuk keputusan nyata:

$ upright("Expected profit positif") ⇏ upright("pasti selamat") $

Kalau variance terlalu besar, perusahaan bisa kehabisan napas sebelum sempat menikmati rata-rata jangka panjangnya.

==== Poin inti
<poin-inti-1>
- Mean mengukur “arah”
- Variance mengukur “ombak”
- Modal awal adalah “bantalan”
- Survival bergantung pada kombinasi mean, variance, dan cadangan modal

=== Latihan singkat
<latihan-singkat-4>
+ Ubah penjualan harian dari Normal menjadi Poisson atau Negative Binomial.
+ Bandingkan peluang bangkrutnya.
+ Mana yang lebih penting ditambah: margin, modal awal, atau pengurangan variance?

== 1.10 Kasus 6 --- Klinik Gigi: Layanan, Throughput, dan Profit
<kasus-6-klinik-gigi-layanan-throughput-dan-profit>
=== K --- Konteks
<k-konteks-6>
Sebuah klinik gigi buka 8 jam per hari. Satu dokter rata-rata memerlukan 30 menit untuk melayani seorang pasien. Karena jenis keluhan pasien berbeda-beda, waktu layanan bersifat acak dan dianggap memoryless. Rata-rata pasien datang 16 orang per hari.

Pertanyaan awal: - berapa rata-rata pasien yang dapat dilayani satu dokter per hari? - berapa distribusi profit harian jika dokter dibayar tetap dan pasien membayar proporsional dengan durasi layanan?

=== M --- Model
<m-model-6>
Klinik buka 8 jam = 480 menit per hari. \
Jika satu layanan rata-rata 30 menit, maka laju layanan dokter:

$ mu = 2 upright(" pasien/jam") $

Jika rata-rata pasien datang 16 per hari dalam 8 jam, maka laju kedatangan:

$ lambda = 2 upright(" pasien/jam") $

Ini adalah model #strong[M/M/1]: - kedatangan Poisson, - layanan Eksponensial, - satu pelayan.

Untuk profit: - gaji dokter = \$350/hari - biaya operasional = \$200/hari - pasien membayar \$1/menit layanan

Jika total waktu layanan aktual dalam sehari adalah $B$ menit, maka:

$ upright("Revenue") = B $ $ upright("Profit") = B - 350 - 200 = B - 550 $

Karena $B lt.eq 480$, maka profit maksimum:

$ 480 - 550 = - 70 $

Artinya klinik pasti rugi pada tarif \$1/menit.

=== Q --- Questions
<q-questions-6>
+ Berapa rata-rata pasien yang selesai dilayani per hari?
+ Bagaimana histogram pasien terlayani per hari?
+ Bagaimana distribusi profit per hari?
+ Jika ada dua dokter, apa yang berubah pada throughput dan profit?

=== A --- Apply
<a-apply-6>
#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("42");#NormalTok(")");],
[],
[#KeywordTok("def");#NormalTok(" simulate_mm1_day(arrival_rate_per_hour");#OperatorTok("=");#FloatTok("2.0");#NormalTok(", service_rate_per_hour");#OperatorTok("=");#FloatTok("2.0");#NormalTok(", hours");#OperatorTok("=");#FloatTok("8.0");#NormalTok("):");],
[#NormalTok("    ");#CommentTok("## Generate arrivals");],
[#NormalTok("    arrivals ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("    t ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.0");],
[#NormalTok("    ");#ControlFlowTok("while");#NormalTok(" ");#VariableTok("True");#NormalTok(":");],
[#NormalTok("        t ");#OperatorTok("+=");#NormalTok(" rng.exponential(scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("arrival_rate_per_hour)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" t ");#OperatorTok(">");#NormalTok(" hours:");],
[#NormalTok("            ");#ControlFlowTok("break");],
[#NormalTok("        arrivals.append(t)");],
[],
[#NormalTok("    service_end_prev ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.0");],
[#NormalTok("    served_count ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    busy_hours ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.0");],
[],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" a ");#KeywordTok("in");#NormalTok(" arrivals:");],
[#NormalTok("        service_time ");#OperatorTok("=");#NormalTok(" rng.exponential(scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("service_rate_per_hour)");],
[#NormalTok("        start ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(a, service_end_prev)");],
[#NormalTok("        end ");#OperatorTok("=");#NormalTok(" start ");#OperatorTok("+");#NormalTok(" service_time");],
[],
[#NormalTok("        overlap_start ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(start, ");#FloatTok("0.0");#NormalTok(")");],
[#NormalTok("        overlap_end ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("min");#NormalTok("(end, hours)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" overlap_end ");#OperatorTok(">");#NormalTok(" overlap_start:");],
[#NormalTok("            busy_hours ");#OperatorTok("+=");#NormalTok(" overlap_end ");#OperatorTok("-");#NormalTok(" overlap_start");],
[],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" end ");#OperatorTok("<=");#NormalTok(" hours:");],
[#NormalTok("            served_count ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("            service_end_prev ");#OperatorTok("=");#NormalTok(" end");],
[#NormalTok("        ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("break");],
[],
[#NormalTok("    busy_minutes ");#OperatorTok("=");#NormalTok(" ");#DecValTok("60");#NormalTok(" ");#OperatorTok("*");#NormalTok(" busy_hours");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" served_count, busy_minutes");],));
]
#block[
#Skylighting(([#NormalTok("served ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("profits ");#OperatorTok("=");#NormalTok(" []");],
[],
[#NormalTok("salary_per_doctor ");#OperatorTok("=");#NormalTok(" ");#DecValTok("300");],
[#NormalTok("no_of_doctor ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("service_rate_per_doctor_per_hour ");#OperatorTok("=");#NormalTok(" ");#FloatTok("2.0");#NormalTok(" ");],
[#NormalTok("operational_cost_per_day");#OperatorTok("=");#DecValTok("200");],
[#NormalTok("revenue_per_minute");#OperatorTok("=");#DecValTok("2");],
[],
[],
[#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("10000");#NormalTok("):");],
[#NormalTok("    s, b ");#OperatorTok("=");#NormalTok(" simulate_mm1_day(arrival_rate_per_hour");#OperatorTok("=");#FloatTok("2.0");#NormalTok(", service_rate_per_hour");#OperatorTok("=");#NormalTok("no_of_doctor");#OperatorTok("*");#NormalTok("service_rate_per_doctor_per_hour, hours");#OperatorTok("=");#FloatTok("8.0");#NormalTok(")");],
[#NormalTok("    served.append(s)");],
[#NormalTok("    profits.append(revenue_per_minute ");#OperatorTok("*");#NormalTok(" b ");#OperatorTok("-");#NormalTok(" no_of_doctor ");#OperatorTok("*");#NormalTok(" salary_per_doctor ");#OperatorTok("-");#NormalTok(" operational_cost_per_day)");],
[],
[#NormalTok("served ");#OperatorTok("=");#NormalTok(" np.array(served)");],
[#NormalTok("profits ");#OperatorTok("=");#NormalTok(" np.array(profits)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rata-rata pasien terlayani per hari =\"");#NormalTok(", served.mean())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rata-rata profit per hari =\"");#NormalTok(", profits.mean())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Profit maksimum simulasi =\"");#NormalTok(", profits.");#BuiltInTok("max");#NormalTok("())");],));
#block[
#Skylighting(([#NormalTok("Rata-rata pasien terlayani per hari = 11.995");],
[#NormalTok("Rata-rata profit per hari = 218.96898501959993");],
[#NormalTok("Profit maksimum simulasi = 459.8579788323201");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("9");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("bins ");#OperatorTok("=");#NormalTok(" np.arange(served.");#BuiltInTok("min");#NormalTok("()");#OperatorTok("-");#FloatTok("0.5");#NormalTok(", served.");#BuiltInTok("max");#NormalTok("()");#OperatorTok("+");#FloatTok("1.5");#NormalTok(", ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("plt.hist(served, bins");#OperatorTok("=");#NormalTok("bins, density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.75");#NormalTok(", edgecolor");#OperatorTok("=");#StringTok("'black'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Jumlah pasien selesai dilayani\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Probabilitas relatif\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Histogram jumlah pasien terlayani per hari\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("01-pendahuluan-pengambilan-keputusan_files/figure-typst/cell-17-output-1.svg"))

#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("9");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(profits, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.75");#NormalTok(", edgecolor");#OperatorTok("=");#StringTok("'black'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Profit per hari ($)\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Distribusi profit per hari klinik gigi\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("01-pendahuluan-pengambilan-keputusan_files/figure-typst/cell-18-output-1.svg"))

==== Interpretasi
<interpretasi-5>
Kasus ini mengajarkan beberapa hal sekaligus: - kapasitas rata-rata dokter, - pengaruh ketidakpastian layanan dan kedatangan, - perbedaan antara “rata-rata teoretis” dan “jumlah selesai terlayani sebelum tutup”, - kaitan antara model antrian dan model profit.

Untuk dua dokter, throughput meningkat, tetapi biaya tetap juga naik. Keputusan menambah dokter harus menimbang: - peningkatan kapasitas, - perubahan waiting time, - perubahan busy time, - dan perubahan profit.

=== Latihan singkat
<latihan-singkat-5>
+ Simulasikan versi dua dokter.
+ Bandingkan histogram pasien terlayani.
+ Cari tarif minimum per menit agar secara teori klinik bisa impas.

== 1.11 Menyimpulkan Bab Ini
<menyimpulkan-bab-ini>
Bab ini memperkenalkan satu ide besar: #strong[probabilitas dan statistika adalah alat untuk membuat keputusan ketika masa depan belum pasti].

Kita telah melihat bahwa: - investasi menuntut kita membandingkan ekspektasi dan risiko, - quality control membutuhkan model jumlah cacat, - garansi produk membutuhkan peluang kegagalan sebelum waktu tertentu, - fungsi random variable penting untuk keselamatan sistem, - variance dapat membuat perusahaan bangkrut walaupun mean profit positif, - model antrian dapat menjelaskan throughput dan profit layanan.

Di balik semua contoh itu, ada benang merah yang sama: kita memerlukan cara untuk memetakan ketidakpastian menjadi objek yang bisa dihitung. Itulah peran random variable.

== 1.12 Ringkasan Poin Inti
<ringkasan-poin-inti>
+ #strong[Pengambilan keputusan] adalah konteks alami bagi probabilitas dan statistika.
+ #strong[Random variable] memetakan dunia acak ke bilangan.
+ #strong[Ekspektasi] membantu kita melihat kecenderungan rata-rata.
+ #strong[Varians] membantu kita mengukur seberapa liar hasil yang mungkin terjadi.
+ #strong[Python] memberi quick wins: melihat, mensimulasikan, dan memahami sebelum formalisasi penuh.
+ #strong[Model yang tepat] penting: Binomial, Poisson, Normal, Exponential, dan lainnya tidak dapat dipertukarkan sembarangan.
+ Dalam banyak masalah nyata, keputusan yang baik tidak cukup melihat mean; ia juga harus melihat #strong[risiko, bentuk distribusi, dan konsekuensi].

== 1.13 Latihan Bab 1
<latihan-bab-1>
=== A. Konseptual
<a.-konseptual>
+ Mengapa mean saja tidak cukup untuk membandingkan dua pilihan?
+ Apa perbedaan antara hasil acak dan random variable?
+ Mengapa keputusan garansi produk adalah masalah probabilistik?

=== B. Komputasional
<b.-komputasional>
+ Simulasikan dua investasi dengan mean sama tetapi variance berbeda.
+ Hitung peluang tepat 3 produk cacat dari 100 jika $p = 0.02$.
+ Hitung peluang sebuah lampu rusak sebelum 850 jam jika umur lampu normal dengan mean 900 dan simpangan baku 60.

=== C. Aplikatif
<c.-aplikatif>
+ Dalam kasus perusahaan, apakah Anda lebih memilih menaikkan margin, menambah modal awal, atau menurunkan variance penjualan? Jelaskan.
+ Dalam kasus klinik gigi, apakah Anda akan menambah dokter kedua jika tarif masih \$1/menit? Mengapa?
+ Berikan satu contoh lain dari kehidupan sehari-hari yang menurut Anda cocok dimodelkan dengan random variable.

== 1.14 Penutup Kecil
<penutup-kecil>
Kalau setelah membaca bab ini Anda merasa, “Ternyata probabilitas bukan sekadar rumus, tetapi cara berpikir,” maka bab ini sudah mencapai tujuannya.

Di bab berikutnya, kita akan memperdalam apa sebenarnya random variable itu, bagaimana range-nya didefinisikan, dan bagaimana PMF, CDF, PDF, ekspektasi, serta varians menjadi fondasi seluruh analisis berikutnya.

= Bab 2. Random Variable Umum
<bab-2.-random-variable-umum>
== Tujuan Bab
<tujuan-bab-1>
Setelah mempelajari bab ini, mahasiswa diharapkan mampu:

+ memahami #strong[random variable] sebagai pemetaan dari hasil acak ke bilangan,
+ membedakan #strong[event] dengan #strong[nilai random variable],
+ memahami #strong[range] sebagai himpunan nilai yang mungkin,
+ membedakan random variable #strong[diskrit] dan #strong[kontinu],
+ memahami dan menggunakan #strong[PMF], #strong[CDF], dan #strong[PDF],
+ menghitung dan menafsirkan #strong[ekspektasi], #strong[varians], dan #strong[simpangan baku],
+ menghubungkan ukuran-ukuran tersebut dengan #strong[pengambilan keputusan].

== Pembuka
<pembuka-1>
Pada bab sebelumnya, kita sudah melihat bahwa probabilitas menjadi penting ketika kita harus mengambil keputusan di bawah ketidakpastian. Kita juga sudah melihat bahwa salah satu cara paling kuat untuk “menjinakkan” ketidakpastian adalah dengan membuat #strong[model].

Di bab ini, kita masuk ke fondasi model tersebut: #strong[random variable].

Random variable adalah salah satu ide yang tampak sederhana, tetapi pengaruhnya sangat besar. Begitu kita berhasil memetakan hasil-hasil acak menjadi angka, kita memperoleh akses ke dunia matematika: kita bisa menggambar, menghitung, mensimulasikan, membandingkan, dan akhirnya memutuskan.

== 2.1 Quick Win: Dari Dunia Acak ke Garis Bilangan
<quick-win-dari-dunia-acak-ke-garis-bilangan>
Mari mulai dari contoh sederhana. Misalkan kita melempar dua koin. Ruang sampelnya adalah:

$ S = { H H \, H T \, T H \, T T } $

Sekarang definisikan random variable:

$ X = upright("jumlah sisi Head yang muncul") $

Maka: - $X \( H H \) = 2$ - $X \( H T \) = 1$ - $X \( T H \) = 1$ - $X \( T T \) = 0$

Artinya, hasil-hasil acak yang tadinya berupa simbol $H H \, H T \, T H \, T T$ dipetakan menjadi angka $0 \, 1 \, 2$.

Mari lihat dengan Python.

#Skylighting(([#ImportTok("import");#NormalTok(" itertools");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("outcomes ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("list");#NormalTok("(itertools.product([");#StringTok("'H'");#NormalTok(", ");#StringTok("'T'");#NormalTok("], repeat");#OperatorTok("=");#DecValTok("2");#NormalTok("))");],
[],
[#KeywordTok("def");#NormalTok(" X(outcome):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" outcome.count(");#StringTok("'H'");#NormalTok(")");],
[],
[#NormalTok("mapped ");#OperatorTok("=");#NormalTok(" [(o, X(o)) ");#ControlFlowTok("for");#NormalTok(" o ");#KeywordTok("in");#NormalTok(" outcomes]");],
[#NormalTok("mapped");],));
#Skylighting(([#NormalTok("[(('H', 'H'), 2), (('H', 'T'), 1), (('T', 'H'), 1), (('T', 'T'), 0)]");],));
#Skylighting(([#NormalTok("values ");#OperatorTok("=");#NormalTok(" [X(o) ");#ControlFlowTok("for");#NormalTok(" o ");#KeywordTok("in");#NormalTok(" outcomes]");],
[#NormalTok("unique, counts ");#OperatorTok("=");#NormalTok(" np.unique(values, return_counts");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.bar(unique, counts ");#OperatorTok("/");#NormalTok(" counts.");#BuiltInTok("sum");#NormalTok("())");],
[#NormalTok("plt.xlabel(");#StringTok("\"Nilai X = jumlah Head\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Probabilitas\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Random variable sebagai pemetaan ke bilangan\"");#NormalTok(")");],
[#NormalTok("plt.xticks(unique)");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("02-random-variable-umum_files/figure-typst/cell-3-output-1.svg"))

Dari sini kita melihat #emph[quick win] yang penting: - event hidup di ruang sampel, - random variable memetakan event ke angka, - distribusi random variable memberi tahu kita bagaimana peluang tersebar pada angka-angka itu.

== 2.2 K --- Konteks: Mengapa Kita Perlu Random Variable?
<k-konteks-mengapa-kita-perlu-random-variable>
Bayangkan beberapa pertanyaan berikut: - Berapa jumlah kendaraan yang lewat gerbang tol dalam satu jam? - Berapa waktu tunggu pasien sampai dilayani? - Berapa profit harian sebuah klinik? - Berapa banyak produk cacat dalam 100 unit? - Berapa lama sebuah lampu bertahan sebelum rusak?

Semua pertanyaan ini punya satu pola: hasilnya #strong[tidak pasti], tetapi hasil itu #strong[berupa bilangan].

Itulah alasan random variable menjadi penting. Ia menjadi jembatan antara: - kejadian acak di dunia nyata, dan - analisis matematis berbasis angka.

== 2.3 M --- Model: Definisi Random Variable
<m-model-definisi-random-variable>
Secara formal, random variable $X$ adalah sebuah fungsi yang memetakan setiap hasil $omega$ dalam ruang sampel $S$ ke sebuah bilangan real:

$ X : S arrow.r bb(R) $

dengan

$ omega mapsto X \( omega \) $

Di sini: - $S$ = ruang sampel, - $omega$ = satu hasil acak, - $X \( omega \)$ = angka yang dihasilkan oleh pemetaan itu.

=== Catatan penting
<catatan-penting>
Random variable bukan “angka yang acak” dalam arti longgar. Secara matematis, random variable adalah #strong[fungsi]. Keacakan datang dari kenyataan bahwa hasil $omega$ belum diketahui sebelum eksperimen terjadi.

== 2.4 Event vs Nilai Random Variable
<event-vs-nilai-random-variable>
Mahasiswa sering bingung membedakan dua hal ini:

- #strong[event] = himpunan hasil dalam ruang sampel,
- #strong[nilai random variable] = angka hasil pemetaan.

Contoh: lempar dua dadu, lalu definisikan

$ X = upright("jumlah mata dadu") $

Maka event: $ E = { \( 1 \, 6 \) \, \( 2 \, 5 \) \, \( 3 \, 4 \) \, \( 4 \, 3 \) \, \( 5 \, 2 \) \, \( 6 \, 1 \) } $

adalah event “jumlah mata dadu = 7”.

Tetapi nilai random variable yang terkait adalah: $ X = 7 $

Jadi: - event adalah kumpulan outcome, - random variable adalah angka yang dihasilkan dari outcome itu.

Mari visualisasikan cepat.

#Skylighting(([#NormalTok("outcomes ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("list");#NormalTok("(itertools.product(");#BuiltInTok("range");#NormalTok("(");#DecValTok("1");#NormalTok(", ");#DecValTok("7");#NormalTok("), repeat");#OperatorTok("=");#DecValTok("2");#NormalTok("))");],
[#NormalTok("sums ");#OperatorTok("=");#NormalTok(" [");#BuiltInTok("sum");#NormalTok("(o) ");#ControlFlowTok("for");#NormalTok(" o ");#KeywordTok("in");#NormalTok(" outcomes]");],
[],
[#NormalTok("unique, counts ");#OperatorTok("=");#NormalTok(" np.unique(sums, return_counts");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("probs ");#OperatorTok("=");#NormalTok(" counts ");#OperatorTok("/");#NormalTok(" counts.");#BuiltInTok("sum");#NormalTok("()");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.bar(unique, probs)");],
[#NormalTok("plt.xlabel(");#StringTok("\"Nilai X = jumlah dua dadu\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Probabilitas\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Distribusi random variable jumlah dua dadu\"");#NormalTok(")");],
[#NormalTok("plt.xticks(unique)");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("02-random-variable-umum_files/figure-typst/cell-4-output-1.svg"))

== 2.5 Range: Nilai-Nilai yang Mungkin
<range-nilai-nilai-yang-mungkin>
Range dari random variable adalah himpunan semua nilai yang mungkin diambil oleh random variable tersebut.

Untuk contoh dua dadu dengan: $ X = upright("jumlah mata dadu") $

range-nya adalah: $ { 2 \, 3 \, 4 \, dots.h \, 12 } $

Range ini penting karena memberi tahu: - apa saja kemungkinan nilai, - apakah nilai-nilai itu diskrit atau kontinu, - bagaimana bentuk distribusinya.

=== Diskrit vs Kontinu
<diskrit-vs-kontinu>
==== Random Variable Diskrit
<random-variable-diskrit>
Jika range terdiri dari titik-titik terpisah, misalnya: $ { 0 \, 1 \, 2 \, 3 \, dots.h } $ maka random variable itu diskrit.

Contoh: - jumlah pelanggan datang, - jumlah cacat, - jumlah pesan masuk, - banyaknya Head.

==== Random Variable Kontinu
<random-variable-kontinu>
Jika range berupa interval pada garis bilangan, misalnya: $ \[ 0 \, oo \) $ atau $ \( - oo \, oo \) $ maka random variable itu kontinu.

Contoh: - waktu tunggu, - lama hidup komponen, - tinggi badan, - suhu.

== 2.6 PMF untuk Random Variable Diskrit
<pmf-untuk-random-variable-diskrit>
Jika $X$ diskrit, maka distribusinya dapat dinyatakan dengan #strong[Probability Mass Function (PMF)]:

$ p_X \( x \) = P \( X = x \) $

PMF memberi peluang bahwa random variable mengambil nilai tepat $x$.

=== Sifat PMF
<sifat-pmf>
+ $ p_X \( x \) gt.eq 0 $

+ $ sum_x p_X \( x \) = 1 $

==== Contoh: jumlah Head pada dua lemparan koin
<contoh-jumlah-head-pada-dua-lemparan-koin>
$ P \( X = 0 \) = 1 / 4 \, quad P \( X = 1 \) = 1 / 2 \, quad P \( X = 2 \) = 1 / 4 $

#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok("])");],
[#NormalTok("pmf ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("1");#OperatorTok("/");#DecValTok("4");#NormalTok(", ");#DecValTok("1");#OperatorTok("/");#DecValTok("2");#NormalTok(", ");#DecValTok("1");#OperatorTok("/");#DecValTok("4");#NormalTok("])");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.stem(x, pmf, basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"P(X=x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PMF jumlah Head pada dua lemparan koin\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("02-random-variable-umum_files/figure-typst/cell-5-output-1.svg"))

==== Interpretasi keputusan
<interpretasi-keputusan>
PMF membantu menjawab pertanyaan seperti: - seberapa mungkin tepat 2 cacat? - seberapa mungkin tepat 5 pelanggan datang? - seberapa mungkin tepat 1 dari 3 server gagal?

== 2.7 CDF: Bahasa Probabilitas Kumulatif
<cdf-bahasa-probabilitas-kumulatif>
Baik untuk random variable diskrit maupun kontinu, salah satu fungsi terpenting adalah #strong[Cumulative Distribution Function (CDF)]:

$ F_X \( x \) = P \( X lt.eq x \) $

CDF memberi peluang bahwa nilai random variable #strong[tidak melebihi] $x$.

Ini sangat penting karena banyak keputusan berbentuk: - peluang rusak sebelum waktu tertentu, - peluang demand tidak melebihi stok, - peluang profit lebih kecil dari nol, - peluang nilai ujian di bawah batas lulus.

==== Contoh CDF diskrit
<contoh-cdf-diskrit>
Untuk $X$ = jumlah Head pada dua lemparan koin: - $F \( 0 \) = P \( X lt.eq 0 \) = 1 \/ 4$ - $F \( 1 \) = P \( X lt.eq 1 \) = 3 \/ 4$ - $F \( 2 \) = 1$

#Skylighting(([#NormalTok("cdf ");#OperatorTok("=");#NormalTok(" np.cumsum(pmf)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.step(x, cdf, where");#OperatorTok("=");#StringTok("'post'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"F(x)=P(X≤x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"CDF random variable diskrit\"");#NormalTok(")");],
[#NormalTok("plt.ylim(");#OperatorTok("-");#FloatTok("0.05");#NormalTok(", ");#FloatTok("1.05");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("02-random-variable-umum_files/figure-typst/cell-6-output-1.svg"))

== 2.8 PDF untuk Random Variable Kontinu
<pdf-untuk-random-variable-kontinu>
Untuk random variable kontinu, kita biasanya tidak berbicara tentang peluang tepat pada satu titik, karena:

$ P \( X = x \) = 0 $

Sebagai gantinya, distribusi dijelaskan dengan #strong[Probability Density Function (PDF)]:

$ f_X \( x \) $

Peluang pada interval diperoleh melalui integral:

$ P \( a lt.eq X lt.eq b \) = integral_a^b f_X \( x \) thin d x $

=== Sifat PDF
<sifat-pdf>
+ $ f_X \( x \) gt.eq 0 $

+ $ integral_(- oo)^oo f_X \( x \) thin d x = 1 $

==== Contoh cepat: Uniform kontinu pada \[0,1\]
<contoh-cepat-uniform-kontinu-pada-01>
$ f \( x \) = cases(delim: "{", 1 \, & 0 lt.eq x lt.eq 1, 0 \, & upright("lainnya")) $

Maka: $ P \( 0.2 lt.eq X lt.eq 0.7 \) = 0.5 $

#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#FloatTok("0.2");#NormalTok(", ");#FloatTok("1.2");#NormalTok(", ");#DecValTok("400");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" np.where((x ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("0");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (x ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("1");#NormalTok("), ");#FloatTok("1.0");#NormalTok(", ");#FloatTok("0.0");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.fill_between(x, ");#DecValTok("0");#NormalTok(", pdf, where");#OperatorTok("=");#NormalTok("((x ");#OperatorTok(">=");#NormalTok(" ");#FloatTok("0.2");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (x ");#OperatorTok("<=");#NormalTok(" ");#FloatTok("0.7");#NormalTok(")), alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF Uniform(0,1)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("02-random-variable-umum_files/figure-typst/cell-7-output-1.svg"))

==== Interpretasi penting
<interpretasi-penting>
Tinggi PDF bukan peluang langsung. \
Peluang adalah #strong[luas area] di bawah kurva PDF.

== 2.9 Menghubungkan PMF, CDF, dan PDF
<menghubungkan-pmf-cdf-dan-pdf>
Hubungan penting:

=== Untuk diskrit
<untuk-diskrit>
$ F_X \( x \) = sum_(t lt.eq x) p_X \( t \) $

=== Untuk kontinu
<untuk-kontinu>
$ F_X \( x \) = integral_(- oo)^x f_X \( t \) thin d t $

Jika PDF cukup halus, maka: $ f_X \( x \) = frac(d, d x) F_X \( x \) $

Jadi: - PMF/PDF memberi struktur lokal distribusi, - CDF memberi akumulasi peluang sampai titik tertentu.

== 2.10 Ekspektasi: Tebakan Terbaik Sebelum Fakta Terjadi
<ekspektasi-tebakan-terbaik-sebelum-fakta-terjadi>
Ekspektasi adalah ukuran pusat distribusi. Ia sering dipandang sebagai #strong[rata-rata jangka panjang].

=== Untuk random variable diskrit
<untuk-random-variable-diskrit>
$ E \[ X \] = sum_x x thin p_X \( x \) $

=== Untuk random variable kontinu
<untuk-random-variable-kontinu>
$ E \[ X \] = integral_(- oo)^oo x f_X \( x \) thin d x $

==== Contoh: jumlah Head pada dua lemparan koin
<contoh-jumlah-head-pada-dua-lemparan-koin-1>
$ E \[ X \] = 0 dot.op 1 / 4 + 1 dot.op 1 / 2 + 2 dot.op 1 / 4 = 1 $

Mari cek dengan simulasi.

#block[
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("123");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100000");],
[#NormalTok("coin1 ");#OperatorTok("=");#NormalTok(" rng.integers(");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok(", size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("coin2 ");#OperatorTok("=");#NormalTok(" rng.integers(");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok(", size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("Xsim ");#OperatorTok("=");#NormalTok(" coin1 ");#OperatorTok("+");#NormalTok(" coin2");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rata-rata simulasi =\"");#NormalTok(", Xsim.mean())");],));
#block[
#Skylighting(([#NormalTok("Rata-rata simulasi = 1.00235");],));
]
]
==== Interpretasi keputusan
<interpretasi-keputusan-1>
Ekspektasi menjawab pertanyaan seperti: - rata-rata keuntungan harian, - rata-rata jumlah pelanggan, - rata-rata cacat per batch, - rata-rata waktu tunggu.

Tetapi ekspektasi #strong[tidak mengatakan seluruh cerita]. Dua distribusi dengan mean sama bisa memiliki risiko yang sangat berbeda.

== 2.11 Varians dan Simpangan Baku: Seberapa Liar Penyimpangannya?
<varians-dan-simpangan-baku-seberapa-liar-penyimpangannya>
Varians mengukur seberapa jauh random variable menyebar dari nilai ekspektasinya.

=== Definisi
<definisi>
$ upright(V a r) \( X \) = E \[ \( X - E \[ X \] \)^2 \] $

Simpangan baku adalah akar kuadrat varians: $ sigma_X = sqrt(upright(V a r) \( X \)) $

=== Bentuk yang sering lebih praktis
<bentuk-yang-sering-lebih-praktis>
$ upright(V a r) \( X \) = E \[ X^2 \] - \( E \[ X \] \)^2 $

==== Contoh: dua investasi dengan mean sama, variance beda
<contoh-dua-investasi-dengan-mean-sama-variance-beda>
#block[
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("2026");#NormalTok(")");],
[],
[#NormalTok("A ");#OperatorTok("=");#NormalTok(" rng.choice([");#DecValTok("8");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("12");#NormalTok("], size");#OperatorTok("=");#DecValTok("100000");#NormalTok(", p");#OperatorTok("=");#NormalTok("[");#FloatTok("0.25");#NormalTok(", ");#FloatTok("0.50");#NormalTok(", ");#FloatTok("0.25");#NormalTok("])");],
[#NormalTok("B ");#OperatorTok("=");#NormalTok(" rng.choice([");#DecValTok("0");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("20");#NormalTok("], size");#OperatorTok("=");#DecValTok("100000");#NormalTok(", p");#OperatorTok("=");#NormalTok("[");#FloatTok("0.25");#NormalTok(", ");#FloatTok("0.50");#NormalTok(", ");#FloatTok("0.25");#NormalTok("])");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean A =\"");#NormalTok(", A.mean(), ");#StringTok("\"Var A =\"");#NormalTok(", A.var(), ");#StringTok("\"Std A =\"");#NormalTok(", A.std())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean B =\"");#NormalTok(", B.mean(), ");#StringTok("\"Var B =\"");#NormalTok(", B.var(), ");#StringTok("\"Std B =\"");#NormalTok(", B.std())");],));
#block[
#Skylighting(([#NormalTok("Mean A = 9.98924 Var A = 2.0013242224 Std A = 1.414681668220805");],
[#NormalTok("Mean B = 9.9584 Var B = 49.78426944 Std B = 7.055796867824356");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(A, bins");#OperatorTok("=");#NormalTok("np.arange(");#OperatorTok("-");#FloatTok("0.5");#NormalTok(", ");#FloatTok("21.5");#NormalTok(", ");#DecValTok("1");#NormalTok("), alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", label");#OperatorTok("=");#StringTok("\"A\"");#NormalTok(")");],
[#NormalTok("plt.hist(B, bins");#OperatorTok("=");#NormalTok("np.arange(");#OperatorTok("-");#FloatTok("0.5");#NormalTok(", ");#FloatTok("21.5");#NormalTok(", ");#DecValTok("1");#NormalTok("), alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", label");#OperatorTok("=");#StringTok("\"B\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Nilai\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density / Probability\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Mean sama, variance berbeda\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("02-random-variable-umum_files/figure-typst/cell-10-output-1.svg"))

==== Interpretasi keputusan
<interpretasi-keputusan-2>
Jika kita hanya melihat mean, dua pilihan ini tampak setara. Tetapi jika kita juga melihat variance, kita sadar bahwa salah satu pilihan jauh lebih berisiko.

== 2.12 Sifat-Sifat Penting Ekspektasi dan Varians
<sifat-sifat-penting-ekspektasi-dan-varians>
=== Linearitas ekspektasi
<linearitas-ekspektasi>
Untuk konstanta $a \, b$: $ E \[ a X + b \] = a E \[ X \] + b $

Ini sangat penting karena memungkinkan kita memindahkan model ke unit baru atau mengubah skala.

=== Varians terhadap transformasi linear
<varians-terhadap-transformasi-linear>
$ upright(V a r) \( a X + b \) = a^2 upright(V a r) \( X \) $

Artinya: - menambah konstanta tidak mengubah variance, - mengalikan skala dengan $a$ memperbesar variance sebesar $a^2$.

Mari cek.

#block[
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("0");#NormalTok(")");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#DecValTok("5");#NormalTok(", scale");#OperatorTok("=");#DecValTok("2");#NormalTok(", size");#OperatorTok("=");#DecValTok("100000");#NormalTok(")");],
[],
[#NormalTok("Y ");#OperatorTok("=");#NormalTok(" ");#DecValTok("3");#OperatorTok("*");#NormalTok("X ");#OperatorTok("+");#NormalTok(" ");#DecValTok("10");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"E[X] ~\"");#NormalTok(", X.mean())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"E[Y] ~\"");#NormalTok(", Y.mean(), ");#StringTok("\"   teori =\"");#NormalTok(", ");#DecValTok("3");#OperatorTok("*");#NormalTok("X.mean() ");#OperatorTok("+");#NormalTok(" ");#DecValTok("10");#NormalTok(")");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Var[X] ~\"");#NormalTok(", X.var())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Var[Y] ~\"");#NormalTok(", Y.var(), ");#StringTok("\"   teori =\"");#NormalTok(", ");#DecValTok("9");#OperatorTok("*");#NormalTok("X.var())");],));
#block[
#Skylighting(([#NormalTok("E[X] ~ 4.998183498453758");],
[#NormalTok("E[Y] ~ 24.994550495361278    teori = 24.994550495361274");],
[#NormalTok("Var[X] ~ 4.001028098478324");],
[#NormalTok("Var[Y] ~ 36.00925288630492    teori = 36.009252886304914");],));
]
]
== 2.13 Diskrit dan Kontinu dalam Praktik
<diskrit-dan-kontinu-dalam-praktik>
Secara praktik, banyak data diukur secara diskrit: - berat badan dibulatkan ke 0.1 kg, - waktu dicatat dalam detik, - panjang dicatat dalam milimeter.

Tetapi secara model, kadang jauh lebih sederhana menganggap besaran itu kontinu. Ini bukan kesalahan, tetapi bentuk idealisasi yang membantu analisis.

=== Pedoman intuitif
<pedoman-intuitif>
- Jika nilai alami berupa hitungan → cenderung diskrit
- Jika nilai alami berupa pengukuran halus → sering dimodelkan kontinu

Contoh: - jumlah mobil → diskrit - waktu hidup lampu → kontinu - jumlah pasien → diskrit - suhu → kontinu

== 2.14 Dari Histogram ke Distribusi
<dari-histogram-ke-distribusi>
Dalam kenyataan, kita sering tidak mulai dari rumus distribusi, tetapi dari data. Dari data, kita bisa membuat histogram untuk melihat bentuk penyebaran.

Mari contohkan data simulasi.

#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("99");#NormalTok(")");],
[#NormalTok("samples ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#DecValTok("100");#NormalTok(", scale");#OperatorTok("=");#DecValTok("15");#NormalTok(", size");#OperatorTok("=");#DecValTok("5000");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(samples, bins");#OperatorTok("=");#DecValTok("40");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.75");#NormalTok(", edgecolor");#OperatorTok("=");#StringTok("'black'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Nilai\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Histogram sebagai pendekatan bentuk distribusi\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("02-random-variable-umum_files/figure-typst/cell-12-output-1.svg"))

Histogram tidak otomatis menjadi PMF atau PDF yang eksak, tetapi histogram sangat berguna untuk: - menduga bentuk distribusi, - melihat pusat, - melihat penyebaran, - mendeteksi skewness atau outlier, - memilih model awal yang masuk akal.

== 2.15 KMQA Mini-Case 1 --- Timbangan Berat Badan
<kmqa-mini-case-1-timbangan-berat-badan>
=== K --- Konteks
<k-konteks-7>
Sebuah timbangan digital menampilkan berat badan dalam satu angka desimal.

=== M --- Model
<m-model-7>
Jika $X$ adalah berat badan orang yang naik ke timbangan, maka $X$ dapat dimodelkan sebagai random variable kontinu, walaupun tampilan akhirnya dibulatkan.

=== Q --- Questions
<q-questions-7>
+ Apa range masuk akalnya?
+ Apakah lebih masuk akal dipandang diskrit atau kontinu?
+ Ukuran apa yang penting: mean, variance, atau keduanya?

=== A --- Apply
<a-apply-7>
Jawabannya: - range teknis mungkin 0--999.9, tetapi range realistis jauh lebih sempit, - secara teori lebih nyaman dipandang kontinu, - mean memberi pusat berat populasi, - variance memberi seberapa beragam berat badan orang yang diukur.

== 2.16 KMQA Mini-Case 2 --- Jumlah Kendaraan di Gerbang Tol
<kmqa-mini-case-2-jumlah-kendaraan-di-gerbang-tol>
=== K --- Konteks
<k-konteks-8>
Kita ingin memodelkan jumlah kendaraan yang lewat dalam satu jam.

=== M --- Model
<m-model-8>
Jika $X$ = jumlah kendaraan, maka $X$ adalah random variable diskrit.

=== Q --- Questions
<q-questions-8>
+ Mengapa diskrit?
+ Apa range yang masuk akal?
+ Apa arti $P \( X = 120 \)$? Apa arti $P \( X lt.eq 120 \)$?

=== A --- Apply
<a-apply-8>
- diskrit karena berupa hitungan,
- $P \( X = 120 \)$ adalah peluang tepat 120 kendaraan,
- $P \( X lt.eq 120 \)$ adalah peluang jumlah kendaraan tidak melebihi 120.

== 2.17 KMQA Mini-Case 3 --- Waktu Tunggu Pasien
<kmqa-mini-case-3-waktu-tunggu-pasien>
=== K --- Konteks
<k-konteks-9>
Sebuah klinik ingin memodelkan waktu tunggu pasien hingga dilayani.

=== M --- Model
<m-model-9>
Jika $X$ = waktu tunggu (menit), maka $X$ biasanya dimodelkan kontinu.

=== Q --- Questions
<q-questions-9>
+ Mengapa kontinu?
+ Mengapa $P \( X = 10 \) = 0$ tetapi $P \( 9.5 lt.eq X lt.eq 10.5 \)$ bisa positif?
+ Mengapa CDF penting dalam konteks ini?

=== A --- Apply
<a-apply-9>
- kontinu karena waktu dapat berubah halus,
- pada model kontinu, peluang titik tunggal nol,
- yang bermakna adalah peluang interval,
- CDF membantu menjawab “peluang menunggu tidak lebih dari x menit”.

== 2.18 Python Toolbox Dasar untuk Bab Ini
<python-toolbox-dasar-untuk-bab-ini>
Berikut beberapa alat Python yang sangat sering dipakai untuk random variable.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],));
]
=== Simulasi data
<simulasi-data>
#Skylighting(([#NormalTok("sample_binom ");#OperatorTok("=");#NormalTok(" np.random.binomial(n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok(", size");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],
[#NormalTok("sample_norm ");#OperatorTok("=");#NormalTok(" np.random.normal(loc");#OperatorTok("=");#DecValTok("0");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#NormalTok(", size");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],
[],
[#NormalTok("sample_binom, sample_norm[:");#DecValTok("5");#NormalTok("]");],));
#Skylighting(([#NormalTok("(array([5, 5, 1, 5, 2, 4, 4, 1, 3, 3], dtype=int32),");],
[#NormalTok(" array([-1.05393446,  0.89598177, -1.87687854, -1.58005177, -0.81141635]))");],));
=== PMF / PDF / CDF dari SciPy
<pmf-pdf-cdf-dari-scipy>
#Skylighting(([#NormalTok("x_discrete ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", ");#DecValTok("11");#NormalTok(")");],
[#NormalTok("pmf_binom ");#OperatorTok("=");#NormalTok(" stats.binom.pmf(x_discrete, n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok(")");],
[],
[#NormalTok("x_cont ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("3");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("200");#NormalTok(")");],
[#NormalTok("pdf_norm ");#OperatorTok("=");#NormalTok(" stats.norm.pdf(x_cont, loc");#OperatorTok("=");#DecValTok("0");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok("cdf_norm ");#OperatorTok("=");#NormalTok(" stats.norm.cdf(x_cont, loc");#OperatorTok("=");#DecValTok("0");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("pmf_binom[:");#DecValTok("5");#NormalTok("], pdf_norm[:");#DecValTok("5");#NormalTok("], cdf_norm[:");#DecValTok("5");#NormalTok("]");],));
#Skylighting(([#NormalTok("(array([0.00604662, 0.04031078, 0.12093235, 0.21499085, 0.25082266]),");],
[#NormalTok(" array([0.00443185, 0.0048492 , 0.00530104, 0.00578971, 0.00631769]),");],
[#NormalTok(" array([0.0013499 , 0.00148973, 0.00164266, 0.00180976, 0.00199218]))");],));
=== Plot cepat
<plot-cepat>
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.stem(x_discrete, pmf_binom, basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Contoh PMF Binomial dari scipy.stats\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"P(X=x)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("02-random-variable-umum_files/figure-typst/cell-16-output-1.svg"))

== 2.19 Kesalahan-Kesalahan Umum yang Harus Dihindari
<kesalahan-kesalahan-umum-yang-harus-dihindari>
+ #strong[Menganggap random variable sama dengan event] \
  Tidak. Event adalah himpunan outcome. Random variable adalah fungsi ke bilangan.

+ #strong[Menganggap PDF adalah peluang langsung] \
  Tidak. Untuk kontinu, peluang adalah luas area di bawah PDF.

+ #strong[Menganggap mean cukup untuk semua keputusan] \
  Tidak. Variance dan bentuk distribusi juga penting.

+ #strong[Menganggap diskrit dan kontinu bisa dipertukarkan sembarangan] \
  Tidak. Pemilihan model harus sesuai konteks.

+ #strong[Menganggap $P \( X = x \)$ untuk kontinu bisa positif] \
  Tidak. Dalam model kontinu, peluang tepat satu titik adalah nol.

== 2.20 Menyimpulkan Bab Ini
<menyimpulkan-bab-ini-1>
Bab ini memberi fondasi yang akan dipakai terus-menerus pada bab-bab berikutnya.

Kita telah melihat bahwa: - random variable adalah fungsi dari ruang sampel ke bilangan real, - range membantu kita mengenali jenis peubah acak, - PMF dipakai untuk diskrit, - PDF dipakai untuk kontinu, - CDF berlaku untuk keduanya, - ekspektasi memberi ukuran pusat, - varians dan simpangan baku memberi ukuran penyebaran.

Dengan fondasi ini, kita siap masuk ke distribusi-distribusi khusus yang sangat sering dipakai dalam pemodelan nyata.

== 2.21 Ringkasan Poin Inti
<ringkasan-poin-inti-1>
+ #strong[Random variable] memetakan hasil acak menjadi angka.
+ #strong[Event] berbeda dari #strong[nilai random variable].
+ #strong[Range] adalah himpunan nilai yang mungkin diambil.
+ #strong[PMF] untuk diskrit, #strong[PDF] untuk kontinu, dan #strong[CDF] untuk keduanya.
+ #strong[Ekspektasi] mengukur pusat atau rata-rata jangka panjang.
+ #strong[Varians] dan #strong[simpangan baku] mengukur penyebaran.
+ Dalam keputusan nyata, kita hampir selalu perlu melihat lebih dari sekadar mean.

== 2.22 Latihan Bab 2
<latihan-bab-2>
=== A. Konseptual
<a.-konseptual-1>
+ Jelaskan dengan kata-kata sendiri apa itu random variable.
+ Apa perbedaan antara event “jumlah mata dua dadu = 7” dan nilai random variable $X = 7$?
+ Mengapa PDF bukan peluang langsung?

=== B. Hitungan
<b.-hitungan>
+ Untuk dua lemparan koin, hitung PMF dan CDF dari jumlah Head.
+ Untuk dua dadu fair, hitung:
  - $P \( X = 8 \)$
  - $P \( X lt.eq 8 \)$ dengan $X$ = jumlah dua dadu.
+ Jika $X$ uniform pada \[0,1\], hitung:
  - $P \( X < 0.3 \)$
  - $P \( 0.3 lt.eq X lt.eq 0.8 \)$

=== C. Python
<c.-python>
+ Simulasikan 50.000 lemparan dua koin dan bandingkan histogram hasil dengan PMF teoritis.
+ Simulasikan 50.000 lemparan dua dadu dan gambar CDF empiris jumlah mata dadu.
+ Simulasikan random variable kontinu sederhana dan tunjukkan bahwa peluang titik tunggal mendekati nol.

=== D. Aplikatif
<d.-aplikatif>
+ Sebutkan satu random variable diskrit dan satu kontinu dari kehidupan sehari-hari.
+ Dalam konteks layanan klinik, ukuran mana yang lebih penting: mean waktu tunggu atau peluang menunggu lebih dari 30 menit? Jelaskan.
+ Dalam konteks quality control, mengapa $P \( X lt.eq k \)$ sering lebih berguna daripada hanya $P \( X = k \)$?

== 2.23 Penutup Kecil
<penutup-kecil-1>
Bab ini mungkin terlihat “dasar”, tetapi fondasi yang kuat justru dibuat dari konsep-konsep dasar yang dipahami dengan jernih. Begitu Anda benar-benar memahami random variable, PMF, CDF, PDF, ekspektasi, dan varians, banyak topik berikutnya akan terasa jauh lebih masuk akal.

Di bab berikutnya, kita akan mulai memasuki keluarga-keluarga #strong[distribusi diskrit khusus] yang sangat sering dipakai dalam pemodelan: Bernoulli, Binomial, Geometric, Poisson, dan lainnya.

= Bab 3. Distribusi Random Variable Diskrit
<bab-3.-distribusi-random-variable-diskrit>
== Tujuan Bab
<tujuan-bab-2>
Setelah mempelajari bab ini, mahasiswa diharapkan mampu:

+ memahami apa yang dimaksud dengan #strong[distribusi random variable diskrit],
+ membangun distribusi diskrit dari #strong[data histogram] atau dari #strong[model probabilistik],
+ mengenali dan menggunakan distribusi:
  - discrete uniform,
  - Bernoulli,
  - Binomial,
  - Geometric,
  - Poisson,
+ memahami makna parameter setiap distribusi,
+ menggunakan Python untuk:
  - simulasi,
  - perhitungan PMF/CDF,
  - visualisasi,
  - dan pengambilan keputusan,
+ memilih distribusi diskrit yang tepat untuk konteks masalah tertentu.

== Pembuka
<pembuka-2>
Di bab sebelumnya, kita sudah belajar bahwa random variable adalah cara memetakan dunia acak ke angka. Sekarang kita melangkah lebih jauh: setelah punya random variable, kita perlu tahu #strong[bagaimana peluang tersebar] pada nilai-nilai yang mungkin.

Itulah yang disebut #strong[distribusi].

Untuk random variable diskrit, distribusi memberi jawaban atas pertanyaan seperti: - seberapa mungkin tepat 2 produk cacat? - seberapa mungkin tepat 10 pelanggan datang? - seberapa mungkin perlu 4 kali percobaan sampai sukses pertama? - seberapa mungkin jumlah panggilan masuk dalam satu jam sama dengan 7?

Bab ini akan memperkenalkan keluarga distribusi diskrit yang paling penting dan paling sering dipakai.

== 3.1 Quick Win: Dari Histogram ke Model
<quick-win-dari-histogram-ke-model>
Bayangkan kita mengamati jumlah pelanggan yang datang ke sebuah kios kopi per jam selama beberapa hari, lalu mendapatkan data seperti berikut.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("42");#NormalTok(")");],
[#NormalTok("data ");#OperatorTok("=");#NormalTok(" rng.poisson(lam");#OperatorTok("=");#DecValTok("5");#NormalTok(", size");#OperatorTok("=");#DecValTok("500");#NormalTok(")");],
[],
[#NormalTok("values, counts ");#OperatorTok("=");#NormalTok(" np.unique(data, return_counts");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("probs ");#OperatorTok("=");#NormalTok(" counts ");#OperatorTok("/");#NormalTok(" counts.");#BuiltInTok("sum");#NormalTok("()");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.bar(values, probs)");],
[#NormalTok("plt.xlabel(");#StringTok("\"Jumlah pelanggan per jam\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Frekuensi relatif\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Histogram empiris jumlah pelanggan\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("03-distribusi-diskrit_files/figure-typst/cell-2-output-1.svg"))

Histogram ini belum tentu langsung memberi kita distribusi teoretis, tetapi ia memberi tiga hal penting: 1. range nilai yang mungkin, 2. lokasi pusat distribusi, 3. bentuk kasar penyebaran.

Dari sini kita bisa mulai bertanya: model mana yang paling masuk akal?

== 3.2 Distribusi Diskrit Kustom dari Histogram
<distribusi-diskrit-kustom-dari-histogram>
=== K --- Konteks
<k-konteks-10>
Kadang-kadang kita tidak mulai dari rumus distribusi yang terkenal. Kita mulai dari data empiris. Misalnya: - distribusi nilai kuis, - banyak pelanggan datang per jam, - banyak tiket gangguan per hari, - jumlah pembelian aplikasi per sesi.

=== M --- Model
<m-model-10>
Jika kita sudah punya histogram atau frekuensi relatif, kita bisa memperlakukannya sebagai #strong[PMF empiris]:

$ p_X \( x_i \) approx frac(upright("frekuensi pada ") x_i, upright("total data")) $

Ini adalah distribusi diskrit kustom.

=== Q --- Questions
<q-questions-10>
+ Bagaimana membangun PMF dari data?
+ Bagaimana menghitung CDF empiris?
+ Bagaimana menghitung mean dan variance dari distribusi diskrit yang dibangun dari histogram?

=== A --- Apply
<a-apply-10>
#block[
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" values");],
[#NormalTok("pmf_emp ");#OperatorTok("=");#NormalTok(" probs");],
[],
[#NormalTok("mean_emp ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("(x ");#OperatorTok("*");#NormalTok(" pmf_emp)");],
[#NormalTok("var_emp ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("((x ");#OperatorTok("-");#NormalTok(" mean_emp)");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" pmf_emp)");],
[#NormalTok("cdf_emp ");#OperatorTok("=");#NormalTok(" np.cumsum(pmf_emp)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean empiris =\"");#NormalTok(", mean_emp)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance empiris =\"");#NormalTok(", var_emp)");],));
#block[
#Skylighting(([#NormalTok("Mean empiris = 5.036");],
[#NormalTok("Variance empiris = 4.718704");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.stem(x, pmf_emp, basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"p(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PMF empiris dari histogram\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("03-distribusi-diskrit_files/figure-typst/cell-4-output-1.svg"))

#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.step(x, cdf_emp, where");#OperatorTok("=");#StringTok("'post'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"F(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"CDF empiris\"");#NormalTok(")");],
[#NormalTok("plt.ylim(");#OperatorTok("-");#FloatTok("0.05");#NormalTok(", ");#FloatTok("1.05");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("03-distribusi-diskrit_files/figure-typst/cell-5-output-1.svg"))

==== Interpretasi
<interpretasi-6>
Distribusi diskrit kustom sangat berguna ketika: - kita punya data nyata, - tetapi belum ingin atau belum bisa memaksakan model teoritis tertentu, - dan kita tetap ingin menghitung ekspektasi, varians, serta peluang kumulatif.

=== Ringkasan mini
<ringkasan-mini>
- Histogram dapat menjadi PMF empiris
- Dari PMF empiris kita bisa hitung mean, variance, dan CDF
- Ini adalah langkah awal yang penting sebelum memilih model yang lebih teoritis

== 3.3 Discrete Uniform Distribution
<discrete-uniform-distribution>
=== K --- Konteks
<k-konteks-11>
Ada situasi di mana semua nilai mungkin dianggap sama-sama mungkin. Misalnya: - hasil lemparan dadu fair, - memilih satu nomor secara acak dari 1 sampai 10, - memilih satu hari dari 7 hari secara uniform.

=== M --- Model
<m-model-11>
Jika $X$ uniform diskrit pada ${ a \, a + 1 \, dots.h \, b }$, maka:

$ P \( X = x \) = frac(1, b - a + 1) \, #h(2em) x = a \, a + 1 \, dots.h \, b $

=== Q --- Questions
<q-questions-11>
+ Berapa peluang satu nilai tertentu?
+ Berapa ekspektasi dan variansnya?
+ Kapan asumsi “semua sama mungkin” masuk akal?

=== A --- Apply
<a-apply-11>
#block[
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("1");#NormalTok(", ");#DecValTok("7");#NormalTok(")  ");#CommentTok("## dadu fair");],
[#NormalTok("pmf ");#OperatorTok("=");#NormalTok(" np.ones_like(x) ");#OperatorTok("/");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(x)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", np.");#BuiltInTok("sum");#NormalTok("(x ");#OperatorTok("*");#NormalTok(" pmf))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance =\"");#NormalTok(", np.");#BuiltInTok("sum");#NormalTok("((x ");#OperatorTok("-");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("(x");#OperatorTok("*");#NormalTok("pmf))");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" pmf))");],));
#block[
#Skylighting(([#NormalTok("Mean = 3.5");],
[#NormalTok("Variance = 2.9166666666666665");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.bar(x, pmf)");],
[#NormalTok("plt.xlabel(");#StringTok("\"Mata dadu\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Probabilitas\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Distribusi uniform diskrit pada dadu fair\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("03-distribusi-diskrit_files/figure-typst/cell-7-output-1.svg"))

==== Hasil teoritis
<hasil-teoritis>
Untuk uniform diskrit pada ${ 1 \, 2 \, dots.h \, n }$:

$ E \[ X \] = frac(n + 1, 2) $

$ upright(V a r) \( X \) = frac(n^2 - 1, 12) $

==== Interpretasi keputusan
<interpretasi-keputusan-3>
Distribusi uniform diskrit dipakai ketika tidak ada alasan untuk memberi bobot lebih pada satu nilai dibanding yang lain.

=== Latihan singkat
<latihan-singkat-6>
+ Hitung mean dan variance untuk uniform diskrit pada ${ 3 \, 4 \, dots.h \, 10 }$.
+ Simulasikan 10000 sampel dari distribusi itu.
+ Beri contoh keputusan nyata yang cocok dimodelkan uniform diskrit.

== 3.4 Bernoulli Distribution
<bernoulli-distribution>
=== K --- Konteks
<k-konteks-12>
Banyak keputusan nyata berujung pada dua kemungkinan: - sukses / gagal, - cacat / tidak cacat, - hujan / tidak hujan, - lolos / tidak lolos, - klik / tidak klik.

=== M --- Model
<m-model-12>
Random variable Bernoulli memiliki dua nilai: $ X in { 0 \, 1 } $

dengan: $ P \( X = 1 \) = p \, #h(2em) P \( X = 0 \) = 1 - p $

=== Q --- Questions
<q-questions-12>
+ Apa arti parameter $p$?
+ Berapa ekspektasi dan variansnya?
+ Masalah apa yang paling cocok dimodelkan Bernoulli?

=== A --- Apply
<a-apply-12>
#block[
#Skylighting(([#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.7");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("])");],
[#NormalTok("pmf ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("1");#OperatorTok("-");#NormalTok("p, p])");],
[],
[#NormalTok("mean ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("(x ");#OperatorTok("*");#NormalTok(" pmf)");],
[#NormalTok("var ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("((x ");#OperatorTok("-");#NormalTok(" mean)");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" pmf)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", mean)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance =\"");#NormalTok(", var)");],));
#block[
#Skylighting(([#NormalTok("Mean = 0.7");],
[#NormalTok("Variance = 0.21000000000000002");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.bar(x, pmf)");],
[#NormalTok("plt.xticks([");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("], [");#StringTok("\"0 (gagal)\"");#NormalTok(", ");#StringTok("\"1 (sukses)\"");#NormalTok("])");],
[#NormalTok("plt.ylabel(");#StringTok("\"Probabilitas\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Distribusi Bernoulli\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("03-distribusi-diskrit_files/figure-typst/cell-9-output-1.svg"))

==== Hasil teoritis
<hasil-teoritis-1>
$ E \[ X \] = p $

$ upright(V a r) \( X \) = p \( 1 - p \) $

==== Interpretasi
<interpretasi-7>
Bernoulli adalah batu bata paling dasar bagi banyak distribusi lain. Binomial, misalnya, dibangun dari pengulangan Bernoulli.

=== Latihan singkat
<latihan-singkat-7>
+ Jika peluang klik iklan 0.03, tulis model Bernoullinya.
+ Hitung mean dan variance-nya.
+ Mengapa variance Bernoulli maksimum saat $p = 0.5$?

== 3.5 Binomial Distribution
<binomial-distribution>
=== K --- Konteks
<k-konteks-13>
Sekarang kita beralih dari satu percobaan Bernoulli ke $n$ percobaan Bernoulli independen. \
Contoh: - dari 100 produk, berapa yang cacat? - dari 20 email, berapa yang dibuka? - dari 10 lemparan koin, berapa Head?

=== M --- Model
<m-model-13>
Jika: - ada $n$ percobaan independen, - setiap percobaan punya peluang sukses $p$, - $X$ = jumlah sukses,

maka:

$ X tilde.op upright(B i n o m i a l) \( n \, p \) $

dengan PMF:

$ P \( X = k \) = binom(n, k) p^k \( 1 - p \)^(n - k) \, #h(2em) k = 0 \, 1 \, dots.h \, n $

=== Q --- Questions
<q-questions-13>
+ Bagaimana menghitung peluang tepat $k$ sukses?
+ Berapa ekspektasi dan varians?
+ Kapan Binomial tepat dipakai?

=== A --- Apply
<a-apply-13>
#Skylighting(([#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.3");],
[#NormalTok("k ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", n");#OperatorTok("+");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("pmf ");#OperatorTok("=");#NormalTok(" stats.binom.pmf(k, n");#OperatorTok("=");#NormalTok("n, p");#OperatorTok("=");#NormalTok("p)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.stem(k, pmf, basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Jumlah sukses\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"P(X=k)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PMF Binomial(n=10, p=0.3)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("03-distribusi-diskrit_files/figure-typst/cell-10-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=3) =\"");#NormalTok(", stats.binom.pmf(");#DecValTok("3");#NormalTok(", n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.3");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X<=3) =\"");#NormalTok(", stats.binom.cdf(");#DecValTok("3");#NormalTok(", n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.3");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"E[X] =\"");#NormalTok(", n");#OperatorTok("*");#NormalTok("p)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Var(X) =\"");#NormalTok(", n");#OperatorTok("*");#NormalTok("p");#OperatorTok("*");#NormalTok("(");#DecValTok("1");#OperatorTok("-");#NormalTok("p))");],));
#block[
#Skylighting(([#NormalTok("P(X=3) = 0.2668279319999998");],
[#NormalTok("P(X<=3) = 0.6496107184000001");],
[#NormalTok("E[X] = 3.0");],
[#NormalTok("Var(X) = 2.0999999999999996");],));
]
]
==== Hasil teoritis
<hasil-teoritis-2>
$ E \[ X \] = n p $

$ upright(V a r) \( X \) = n p \( 1 - p \) $

==== Interpretasi keputusan
<interpretasi-keputusan-4>
Gunakan Binomial ketika: - jumlah percobaan tetap, - tiap percobaan independen, - peluang sukses tetap, - yang kita hitung adalah #strong[jumlah sukses].

==== Contoh keputusan QC
<contoh-keputusan-qc>
Jika sebuah pabrik mengklaim tingkat cacat 1%, maka banyak cacat pada sampel 100 unit cocok dimodelkan Binomial(100, 0.01). Dari sana kita bisa menghitung apakah hasil inspeksi masih masuk akal.

=== Latihan singkat
<latihan-singkat-8>
+ Hitung peluang tepat 2 cacat dari 100 unit jika $p = 0.01$.
+ Hitung peluang paling banyak 2 cacat.
+ Simulasikan dan bandingkan hasil empiris dengan PMF teoritis.

== 3.6 Geometric Distribution
<geometric-distribution>
=== K --- Konteks
<k-konteks-14>
Kadang bukan jumlah sukses yang ingin kita hitung, tetapi #strong[berapa lama menunggu sampai sukses pertama].

Contoh: - berapa kali mencoba login sampai berhasil? - berapa banyak panggilan sampai ada yang menjawab? - berapa kali inspeksi sampai menemukan cacat pertama?

=== M --- Model
<m-model-14>
Jika setiap percobaan independen dan peluang sukses tiap percobaan adalah $p$, maka random variable Geometric dapat didefinisikan sebagai:

$ X = upright("jumlah percobaan sampai sukses pertama") $

dengan PMF:

$ P \( X = k \) = \( 1 - p \)^(k - 1) p \, #h(2em) k = 1 \, 2 \, 3 \, dots.h $

=== Q --- Questions
<q-questions-14>
+ Berapa peluang sukses pertama terjadi pada percobaan ke-$k$?
+ Berapa rata-rata jumlah percobaan sampai sukses pertama?
+ Mengapa distribusi ini punya sifat memoryless?

=== A --- Apply
<a-apply-14>
#Skylighting(([#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.25");],
[#NormalTok("k ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("1");#NormalTok(", ");#DecValTok("15");#NormalTok(")");],
[],
[#NormalTok("pmf ");#OperatorTok("=");#NormalTok(" stats.geom.pmf(k, p)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.stem(k, pmf, basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"k = percobaan sampai sukses pertama\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"P(X=k)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PMF Geometric(p=0.25)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("03-distribusi-diskrit_files/figure-typst/cell-12-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=4) =\"");#NormalTok(", stats.geom.pmf(");#DecValTok("4");#NormalTok(", p))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X<=4) =\"");#NormalTok(", stats.geom.cdf(");#DecValTok("4");#NormalTok(", p))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", ");#DecValTok("1");#OperatorTok("/");#NormalTok("p)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance =\"");#NormalTok(", (");#DecValTok("1");#OperatorTok("-");#NormalTok("p)");#OperatorTok("/");#NormalTok("(p");#OperatorTok("**");#DecValTok("2");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("P(X=4) = 0.10546875");],
[#NormalTok("P(X<=4) = 0.68359375");],
[#NormalTok("Mean = 4.0");],
[#NormalTok("Variance = 12.0");],));
]
]
==== Hasil teoritis
<hasil-teoritis-3>
$ E \[ X \] = 1 / p $

$ upright(V a r) \( X \) = frac(1 - p, p^2) $

==== Sifat memoryless
<sifat-memoryless>
Distribusi Geometric memenuhi:

$ P \( X > m + n divides X > m \) = P \( X > n \) $

Artinya, jika kita sudah gagal sampai titik tertentu, peluang menunggu lebih lama lagi tidak “mengingat” masa lalu. Sifat ini akan muncul lagi pada distribusi Eksponensial di bab kontinu.

=== Latihan singkat
<latihan-singkat-9>
+ Jika peluang sukses 0.2, berapa rata-rata jumlah percobaan sampai sukses pertama?
+ Hitung peluang perlu lebih dari 5 percobaan.
+ Verifikasi sifat memoryless dengan simulasi.

== 3.7 Poisson Distribution
<poisson-distribution>
=== K --- Konteks
<k-konteks-15>
Poisson sangat penting untuk memodelkan #strong[jumlah kejadian] dalam suatu interval tetap, ketika kejadian itu: - relatif jarang, - independen, - dan rata-rata kejadian per interval diketahui.

Contoh: - jumlah panggilan masuk per jam, - jumlah pelanggan datang per 10 menit, - jumlah cacat pada lembar besar material, - jumlah kendaraan lewat per menit.

=== M --- Model
<m-model-15>
Jika $X$ = jumlah kejadian dalam interval, dengan rata-rata $lambda$, maka:

$ X tilde.op upright(P o i s s o n) \( lambda \) $

dan PMF-nya:

$ P \( X = k \) = e^(- lambda) frac(lambda^k, k !) \, #h(2em) k = 0 \, 1 \, 2 \, dots.h $

=== Q --- Questions
<q-questions-15>
+ Berapa peluang tepat $k$ kejadian?
+ Mengapa mean dan variance Poisson sama?
+ Kapan Poisson menjadi pendekatan yang baik untuk Binomial?

=== A --- Apply
<a-apply-15>
#Skylighting(([#NormalTok("lam ");#OperatorTok("=");#NormalTok(" ");#DecValTok("4");],
[#NormalTok("k ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", ");#DecValTok("15");#NormalTok(")");],
[],
[#NormalTok("pmf ");#OperatorTok("=");#NormalTok(" stats.poisson.pmf(k, mu");#OperatorTok("=");#NormalTok("lam)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.stem(k, pmf, basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Jumlah kejadian\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"P(X=k)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PMF Poisson(λ=4)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("03-distribusi-diskrit_files/figure-typst/cell-14-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=3) =\"");#NormalTok(", stats.poisson.pmf(");#DecValTok("3");#NormalTok(", mu");#OperatorTok("=");#NormalTok("lam))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X<=3) =\"");#NormalTok(", stats.poisson.cdf(");#DecValTok("3");#NormalTok(", mu");#OperatorTok("=");#NormalTok("lam))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", lam)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance =\"");#NormalTok(", lam)");],));
#block[
#Skylighting(([#NormalTok("P(X=3) = 0.19536681481316454");],
[#NormalTok("P(X<=3) = 0.43347012036670896");],
[#NormalTok("Mean = 4");],
[#NormalTok("Variance = 4");],));
]
]
==== Hasil teoritis
<hasil-teoritis-4>
$ E \[ X \] = lambda $

$ upright(V a r) \( X \) = lambda $

==== Poisson sebagai pendekatan Binomial
<poisson-sebagai-pendekatan-binomial>
Jika: - $n$ besar, - $p$ kecil, - $lambda = n p$ moderat,

maka: $ upright(B i n o m i a l) \( n \, p \) approx upright(P o i s s o n) \( lambda \) $

Mari bandingkan.

#Skylighting(([#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.02");],
[#NormalTok("lam ");#OperatorTok("=");#NormalTok(" n ");#OperatorTok("*");#NormalTok(" p");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", ");#DecValTok("10");#NormalTok(")");],
[],
[#NormalTok("pmf_binom ");#OperatorTok("=");#NormalTok(" stats.binom.pmf(x, n");#OperatorTok("=");#NormalTok("n, p");#OperatorTok("=");#NormalTok("p)");],
[#NormalTok("pmf_pois ");#OperatorTok("=");#NormalTok(" stats.poisson.pmf(x, mu");#OperatorTok("=");#NormalTok("lam)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.stem(x, pmf_binom, linefmt");#OperatorTok("=");#StringTok("'C0-'");#NormalTok(", markerfmt");#OperatorTok("=");#StringTok("'C0o'");#NormalTok(", basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(", label");#OperatorTok("=");#StringTok("'Binomial'");#NormalTok(")");],
[#NormalTok("plt.stem(x");#OperatorTok("+");#FloatTok("0.1");#NormalTok(", pmf_pois, linefmt");#OperatorTok("=");#StringTok("'C1-'");#NormalTok(", markerfmt");#OperatorTok("=");#StringTok("'C1s'");#NormalTok(", basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(", label");#OperatorTok("=");#StringTok("'Poisson approx'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"P(X=x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Pendekatan Poisson terhadap Binomial\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("03-distribusi-diskrit_files/figure-typst/cell-16-output-1.svg"))

==== Interpretasi keputusan
<interpretasi-keputusan-5>
Poisson cocok untuk menghitung volume kedatangan, insiden, atau kejadian jarang dalam interval. Dalam keputusan operasional, ini sangat berguna untuk: - kapasitas layanan, - staffing, - quality control, - reliability.

=== Latihan singkat
<latihan-singkat-10>
+ Jika rata-rata pelanggan datang 5 per jam, hitung peluang tepat 7 pelanggan.
+ Hitung peluang paling banyak 3 pelanggan.
+ Bandingkan hasil Poisson dan Binomial pada kasus kejadian langka.

== 3.8 Memilih Distribusi yang Tepat
<memilih-distribusi-yang-tepat>
Salah satu kemampuan terpenting bukan hanya menghitung, tetapi memilih model yang masuk akal. Berikut panduan ringkas.

=== Bernoulli
<bernoulli>
Gunakan jika: - hanya ada dua hasil, - fokus pada satu percobaan.

Contoh: - klik / tidak klik, - cacat / tidak cacat.

=== Binomial
<binomial>
Gunakan jika: - ada $n$ percobaan independen, - peluang sukses tetap, - fokus pada jumlah sukses.

Contoh: - jumlah cacat dari 100 unit.

=== Geometric
<geometric>
Gunakan jika: - fokus pada berapa lama menunggu sampai sukses pertama, - percobaan independen, - peluang sukses tetap.

Contoh: - jumlah percobaan sampai login berhasil.

=== Poisson
<poisson>
Gunakan jika: - fokus pada jumlah kejadian dalam interval, - rata-rata kejadian diketahui, - kejadian independen dan relatif jarang.

Contoh: - jumlah pasien datang per jam.

=== Uniform diskrit
<uniform-diskrit>
Gunakan jika: - semua nilai dianggap sama mungkin.

Contoh: - hasil dadu fair.

== 3.9 Mini-Case KMQA 1 --- Produk Cacat
<mini-case-kmqa-1-produk-cacat>
=== K --- Konteks
<k-konteks-16>
Pabrik mengklaim tingkat cacat 1%. Tim QC mengambil sampel 100 unit.

=== M --- Model
<m-model-16>
Jika $X$ = jumlah cacat, maka: $ X tilde.op upright("Binomial") \( 100 \, 0.01 \) $

Pendekatan Poisson: $ X approx upright("Poisson") \( 1 \) $

=== Q --- Questions
<q-questions-16>
+ Berapa peluang tepat 2 cacat?
+ Berapa peluang paling banyak 2 cacat?
+ Jika ditemukan 6 cacat, apakah itu masih terasa wajar?

=== A --- Apply
<a-apply-16>
#block[
#Skylighting(([#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.01");],
[#NormalTok("lam ");#OperatorTok("=");#NormalTok(" n");#OperatorTok("*");#NormalTok("p");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=2) Binomial =\"");#NormalTok(", stats.binom.pmf(");#DecValTok("2");#NormalTok(", n, p))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=2) Poisson  =\"");#NormalTok(", stats.poisson.pmf(");#DecValTok("2");#NormalTok(", lam))");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X<=2) Binomial =\"");#NormalTok(", stats.binom.cdf(");#DecValTok("2");#NormalTok(", n, p))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X<=2) Poisson  =\"");#NormalTok(", stats.poisson.cdf(");#DecValTok("2");#NormalTok(", lam))");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X>=6) Binomial =\"");#NormalTok(", ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" stats.binom.cdf(");#DecValTok("5");#NormalTok(", n, p))");],));
#block[
#Skylighting(([#NormalTok("P(X=2) Binomial = 0.18486481882486347");],
[#NormalTok("P(X=2) Poisson  = 0.18393972058572114");],
[#NormalTok("P(X<=2) Binomial = 0.9206267977478195");],
[#NormalTok("P(X<=2) Poisson  = 0.9196986029286058");],
[#NormalTok("P(X>=6) Binomial = 0.0005345344639929861");],));
]
]
==== Interpretasi
<interpretasi-8>
Kalau peluang mendapatkan 6 atau lebih cacat ternyata sangat kecil, maka tim QC pantas curiga bahwa klaim tingkat cacat 1% mungkin tidak lagi valid.

== 3.10 Mini-Case KMQA 2 --- Kedatangan Pelanggan
<mini-case-kmqa-2-kedatangan-pelanggan>
=== K --- Konteks
<k-konteks-17>
Sebuah kios kopi ingin tahu distribusi jumlah pelanggan per jam agar bisa menyiapkan stok dan staf.

=== M --- Model
<m-model-17>
Jika $X$ = jumlah pelanggan datang per jam, gunakan: $ X tilde.op upright("Poisson") \( lambda \) $

=== Q --- Questions
<q-questions-17>
+ Berapa peluang tepat 10 pelanggan datang?
+ Berapa peluang lebih dari 12 pelanggan datang?
+ Apa arti mean dan variance dalam konteks operasional?

=== A --- Apply
<a-apply-17>
#block[
#Skylighting(([#NormalTok("lam ");#OperatorTok("=");#NormalTok(" ");#DecValTok("8");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=10) =\"");#NormalTok(", stats.poisson.pmf(");#DecValTok("10");#NormalTok(", mu");#OperatorTok("=");#NormalTok("lam))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X>12) =\"");#NormalTok(", ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" stats.poisson.cdf(");#DecValTok("12");#NormalTok(", mu");#OperatorTok("=");#NormalTok("lam))");],));
#block[
#Skylighting(([#NormalTok("P(X=10) = 0.09926153383153544");],
[#NormalTok("P(X>12) = 0.06379719673656181");],));
]
]
==== Interpretasi
<interpretasi-9>
Distribusi Poisson membantu kios kopi menilai: - seberapa sering hari ramai, - seberapa besar stok minimum masuk akal, - dan berapa kapasitas pelayanan yang aman.

== 3.11 Mini-Case KMQA 3 --- Login Sampai Berhasil
<mini-case-kmqa-3-login-sampai-berhasil>
=== K --- Konteks
<k-konteks-18>
Sebuah sistem login punya probabilitas sukses 0.8 untuk setiap percobaan independen.

=== M --- Model
<m-model-18>
Jika $X$ = jumlah percobaan sampai sukses pertama: $ X tilde.op upright("Geometric") \( p = 0.8 \) $

=== Q --- Questions
<q-questions-18>
+ Berapa peluang sukses pada percobaan pertama?
+ Berapa peluang butuh lebih dari 3 percobaan?
+ Berapa rata-rata jumlah percobaan sampai berhasil?

=== A --- Apply
<a-apply-18>
#block[
#Skylighting(([#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.8");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=1) =\"");#NormalTok(", stats.geom.pmf(");#DecValTok("1");#NormalTok(", p))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X>3) =\"");#NormalTok(", ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" stats.geom.cdf(");#DecValTok("3");#NormalTok(", p))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", ");#DecValTok("1");#OperatorTok("/");#NormalTok("p)");],));
#block[
#Skylighting(([#NormalTok("P(X=1) = 0.8");],
[#NormalTok("P(X>3) = 0.008000000000000007");],
[#NormalTok("Mean = 1.25");],));
]
]
== 3.12 Python Toolbox untuk Bab Ini
<python-toolbox-untuk-bab-ini>
Berikut beberapa fungsi Python yang sangat sering dipakai.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],));
]
=== Bernoulli
<bernoulli-1>
#Skylighting(([#NormalTok("stats.bernoulli.pmf([");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("], p");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],));
#Skylighting(([#NormalTok("array([0.7, 0.3])");],));
=== Binomial
<binomial-1>
#Skylighting(([#NormalTok("stats.binom.pmf(");#DecValTok("3");#NormalTok(", n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok("), stats.binom.cdf(");#DecValTok("3");#NormalTok(", n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.4");#NormalTok(")");],));
#Skylighting(([#NormalTok("(np.float64(0.21499084799999987), np.float64(0.3822806016))");],));
=== Geometric
<geometric-1>
#Skylighting(([#NormalTok("stats.geom.pmf(");#DecValTok("4");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.2");#NormalTok("), stats.geom.cdf(");#DecValTok("4");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.2");#NormalTok(")");],));
#Skylighting(([#NormalTok("(np.float64(0.10240000000000003), np.float64(0.5904))");],));
=== Poisson
<poisson-1>
#Skylighting(([#NormalTok("stats.poisson.pmf(");#DecValTok("5");#NormalTok(", mu");#OperatorTok("=");#DecValTok("3");#NormalTok("), stats.poisson.cdf(");#DecValTok("5");#NormalTok(", mu");#OperatorTok("=");#DecValTok("3");#NormalTok(")");],));
#Skylighting(([#NormalTok("(np.float64(0.10081881344492458), np.float64(0.9160820579686966))");],));
=== Simulasi
<simulasi>
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("0");#NormalTok(")");],
[#NormalTok("rng.binomial(n");#OperatorTok("=");#DecValTok("10");#NormalTok(", p");#OperatorTok("=");#FloatTok("0.3");#NormalTok(", size");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
#Skylighting(([#NormalTok("array([3, 2, 1, 0, 4, 5, 3, 4, 3, 5])");],));
== 3.13 Kesalahan Umum yang Harus Dihindari
<kesalahan-umum-yang-harus-dihindari>
+ #strong[Salah memilih model] \
  Misalnya memakai Binomial padahal yang ditanya adalah waktu tunggu sampai sukses pertama.

+ #strong[Mencampuradukkan “jumlah sukses” dan “percobaan sampai sukses”] \
  Ini perbedaan Binomial vs Geometric.

+ #strong[Menganggap Poisson untuk semua count data] \
  Tidak. Poisson cocok jika mean dan variance kurang lebih sejalan. Bila variance jauh lebih besar, model lain mungkin lebih cocok.

+ #strong[Lupa memeriksa asumsi independensi dan peluang tetap] \
  Binomial dan Geometric bergantung kuat pada asumsi ini.

+ #strong[Menghafal rumus tanpa memahami konteks] \
  Tujuan bab ini justru agar Anda tahu kapan suatu distribusi relevan.

== 3.14 Menyimpulkan Bab Ini
<menyimpulkan-bab-ini-2>
Distribusi diskrit adalah alat yang sangat kuat untuk memodelkan banyak situasi nyata yang berupa hitungan. Kita telah melihat beberapa keluarga penting:

- #strong[uniform diskrit] untuk nilai-nilai yang sama mungkin,
- #strong[Bernoulli] untuk satu percobaan dua hasil,
- #strong[Binomial] untuk jumlah sukses dari banyak percobaan,
- #strong[Geometric] untuk menunggu sukses pertama,
- #strong[Poisson] untuk jumlah kejadian dalam suatu interval.

Yang terpenting bukan hanya bisa menghitung peluangnya, tetapi juga bisa mengatakan: - apa random variable-nya, - apa arti parameternya, - mengapa model itu masuk akal, - dan keputusan apa yang didukung oleh model itu.

== 3.15 Ringkasan Poin Inti
<ringkasan-poin-inti-2>
+ Distribusi diskrit menjelaskan bagaimana peluang tersebar pada nilai-nilai hitungan.
+ Histogram empiris bisa menjadi langkah awal membangun PMF kustom.
+ #strong[Uniform diskrit] dipakai bila semua nilai sama mungkin.
+ #strong[Bernoulli] memodelkan satu percobaan dua hasil.
+ #strong[Binomial] memodelkan jumlah sukses dari $n$ percobaan independen.
+ #strong[Geometric] memodelkan jumlah percobaan sampai sukses pertama.
+ #strong[Poisson] memodelkan jumlah kejadian dalam interval tetap.
+ Memilih distribusi yang tepat adalah kemampuan yang lebih penting daripada sekadar menghafal rumus.

== 3.16 Latihan Bab 3
<latihan-bab-3>
=== A. Konseptual
<a.-konseptual-2>
+ Jelaskan perbedaan Bernoulli, Binomial, dan Geometric.
+ Mengapa Poisson sering dipakai untuk jumlah kejadian per interval?
+ Kapan uniform diskrit masuk akal, dan kapan tidak?

=== B. Hitungan
<b.-hitungan-1>
+ Sebuah email dibuka dengan peluang 0.2. Modelkan satu email sebagai Bernoulli dan hitung mean serta variance.
+ Dari 20 email independen, hitung peluang tepat 5 terbuka.
+ Jika peluang sukses 0.25, hitung peluang sukses pertama terjadi pada percobaan ke-4.
+ Jika rata-rata panggilan masuk 6 per jam, hitung peluang tepat 8 panggilan masuk.

=== C. Python
<c.-python-1>
+ Simulasikan 50.000 Bernoulli dengan $p = 0.4$, lalu bandingkan mean dan variance simulasi dengan teori.
+ Simulasikan Binomial(20, 0.1) dan bandingkan histogram dengan PMF teoritis.
+ Simulasikan Geometric(0.3) dan verifikasi mean-nya.
+ Simulasikan Poisson(5) dan bandingkan histogram dengan PMF teoritis.

=== D. Aplikatif
<d.-aplikatif-1>
+ Modelkan masalah quality control sederhana dengan Binomial.
+ Modelkan kedatangan pelanggan per jam dengan Poisson.
+ Modelkan percobaan login sampai berhasil dengan Geometric.
+ Jelaskan distribusi mana yang Anda pilih dan mengapa.

== 3.17 Penutup Kecil
<penutup-kecil-2>
Kalau di bab sebelumnya kita baru belajar “apa itu random variable”, maka di bab ini kita mulai benar-benar melihat keluarga model yang bisa dipakai untuk dunia nyata.

Di bab berikutnya, kita akan beralih ke #strong[distribusi random variable kontinu]. Di sana, fokus kita tidak lagi pada hitungan kejadian, tetapi pada besaran seperti waktu, umur hidup, tinggi, jarak, dan banyak pengukuran lain yang lebih nyaman dipandang kontinu.

= Bab 4. Distribusi Random Variable Kontinu
<bab-4.-distribusi-random-variable-kontinu>
== Tujuan Bab
<tujuan-bab-3>
Setelah mempelajari bab ini, mahasiswa diharapkan mampu:

+ memahami perbedaan mendasar antara random variable diskrit dan kontinu,
+ membangun distribusi kontinu sederhana dari tabel selang atau pendekatan trapezoid,
+ mengenali dan menggunakan distribusi kontinu penting:
  - uniform kontinu,
  - normal,
  - gamma,
  - eksponensial,
  - erlang,
  - weibull,
  - pareto,
  - chi-square,
+ memahami hubungan antardistribusi,
+ menggunakan Python untuk simulasi, visualisasi PDF/CDF, dan perhitungan peluang,
+ menghubungkan distribusi kontinu dengan keputusan nyata di bidang teknik, layanan, bisnis, dan reliability.

== Pembuka
<pembuka-3>
Di bab sebelumnya, kita banyak berurusan dengan besaran yang berupa #strong[hitungan]: - jumlah cacat, - jumlah pelanggan, - jumlah sukses, - jumlah percobaan.

Sekarang kita beralih ke dunia yang sedikit berbeda: dunia #strong[pengukuran].

Kita akan memodelkan besaran seperti: - waktu tunggu, - umur hidup lampu, - tinggi badan, - error pengukuran, - besar permintaan, - lama layanan, - dan waktu antar kedatangan.

Pada banyak situasi seperti ini, lebih masuk akal memodelkan nilai sebagai #strong[kontinu]. Nilainya tidak sekadar 0, 1, 2, 3, tetapi berada pada rentang yang halus di garis bilangan.

== 4.1 Quick Win: Mengapa PDF Bukan Peluang Langsung?
<quick-win-mengapa-pdf-bukan-peluang-langsung>
Mari ambil contoh yang sederhana. Misalkan $X$ adalah random variable kontinu yang uniform pada interval \[0, 1\]. Kita tahu PDF-nya adalah:

$ f \( x \) = 1 quad upright("untuk ") 0 lt.eq x lt.eq 1 $

Sekarang pertanyaannya: - berapa $P \( X = 0.5 \)$? - berapa $P \( 0.4 lt.eq X lt.eq 0.6 \)$?

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],
[],
[#CommentTok("## Uniform(0,1)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=0.5) untuk model kontinu = 0\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(0.4 <= X <= 0.6) =\"");#NormalTok(", ");#FloatTok("0.6");#NormalTok(" ");#OperatorTok("-");#NormalTok(" ");#FloatTok("0.4");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("P(X=0.5) untuk model kontinu = 0");],
[#NormalTok("P(0.4 <= X <= 0.6) = 0.19999999999999996");],));
]
]
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#FloatTok("0.2");#NormalTok(", ");#FloatTok("1.2");#NormalTok(", ");#DecValTok("400");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" np.where((x ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("0");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (x ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("1");#NormalTok("), ");#FloatTok("1.0");#NormalTok(", ");#FloatTok("0.0");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.fill_between(x, ");#DecValTok("0");#NormalTok(", pdf, where");#OperatorTok("=");#NormalTok("((x ");#OperatorTok(">=");#NormalTok(" ");#FloatTok("0.4");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (x ");#OperatorTok("<=");#NormalTok(" ");#FloatTok("0.6");#NormalTok(")), alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Pada RV kontinu, peluang = luas area, bukan tinggi kurva\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-3-output-1.svg"))

Dari #emph[quick win] ini kita memperoleh satu pelajaran besar:

#quote(block: true)[
Untuk random variable kontinu, peluang tidak datang dari tinggi titik, tetapi dari #strong[luas area di bawah kurva PDF].
]

== 4.2 Distribusi Kontinu Kustom dari Tabel Selang / Trapezoid
<distribusi-kontinu-kustom-dari-tabel-selang-trapezoid>
=== K --- Konteks
<k-konteks-19>
Kadang kita tidak mulai dari distribusi terkenal seperti Normal atau Exponential. Kita hanya punya perkiraan bentuk dari domain expert atau dari tabel interval. Misalnya: - permintaan produk kemungkinan besar di tengah, menurun di tepi, - usia layanan komponen diperkirakan lebih padat pada interval tertentu, - waktu tempuh berada dalam rentang tertentu dengan perubahan kerapatan yang kasar.

=== M --- Model
<m-model-19>
Kita dapat membentuk PDF kustom dari titik-titik $\( x_i \, f_i \)$, lalu menggunakan interpolasi linier atau pendekatan trapezoid. Selama luas totalnya dinormalisasi menjadi 1, fungsi itu dapat dipakai sebagai PDF.

=== Q --- Questions
<q-questions-19>
+ Bagaimana membangun PDF kontinu dari tabel?
+ Bagaimana memastikan luas total = 1?
+ Bagaimana menghitung peluang interval secara numerik?

=== A --- Apply
<a-apply-19>
#block[
#Skylighting(([#CommentTok("## Titik-titik pembentuk \"density\" mentah");],
[#NormalTok("x_pts ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("6");#NormalTok(", ");#DecValTok("8");#NormalTok(", ");#DecValTok("10");#NormalTok("], dtype");#OperatorTok("=");#BuiltInTok("float");#NormalTok(")");],
[#NormalTok("y_raw ");#OperatorTok("=");#NormalTok(" np.array([");#FloatTok("0.0");#NormalTok(", ");#FloatTok("0.1");#NormalTok(", ");#FloatTok("0.25");#NormalTok(", ");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.08");#NormalTok(", ");#FloatTok("0.0");#NormalTok("], dtype");#OperatorTok("=");#BuiltInTok("float");#NormalTok(")");],
[],
[#CommentTok("## Normalisasi agar integral = 1");],
[#NormalTok("area_raw ");#OperatorTok("=");#NormalTok(" np.trapezoid(y_raw, x_pts)");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" y_raw ");#OperatorTok("/");#NormalTok(" area_raw");],
[],
[#NormalTok("x_grid ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[#NormalTok("y_grid ");#OperatorTok("=");#NormalTok(" np.interp(x_grid, x_pts, y)");],));
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x_grid, y_grid, label");#OperatorTok("=");#StringTok("\"PDF kustom (interpolasi linier)\"");#NormalTok(")");],
[#NormalTok("plt.scatter(x_pts, y, color");#OperatorTok("=");#StringTok("'red'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF kontinu kustom dari tabel selang\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-5-output-1.svg"))

#block[
#Skylighting(([#CommentTok("## Peluang interval [3, 7]");],
[#NormalTok("mask ");#OperatorTok("=");#NormalTok(" (x_grid ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("3");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (x_grid ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("7");#NormalTok(")");],
[#NormalTok("prob_3_7 ");#OperatorTok("=");#NormalTok(" np.trapezoid(y_grid[mask], x_grid[mask])");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(3 <= X <= 7) ~\"");#NormalTok(", prob_3_7)");],
[],
[#CommentTok("## Mean numerik");],
[#NormalTok("mean_num ");#OperatorTok("=");#NormalTok(" np.trapezoid(x_grid ");#OperatorTok("*");#NormalTok(" y_grid, x_grid)");],
[#NormalTok("var_num ");#OperatorTok("=");#NormalTok(" np.trapezoid((x_grid ");#OperatorTok("-");#NormalTok(" mean_num)");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" y_grid, x_grid)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean ~\"");#NormalTok(", mean_num)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance ~\"");#NormalTok(", var_num)");],));
#block[
#Skylighting(([#NormalTok("P(3 <= X <= 7) ~ 0.659204179902892");],
[#NormalTok("Mean ~ 4.825378851610921");],
[#NormalTok("Variance ~ 3.92183354068992");],));
]
]
==== Interpretasi
<interpretasi-10>
Distribusi kontinu kustom penting ketika: - data atau pengetahuan domain belum cukup untuk memilih distribusi tertutup tertentu, - kita tetap ingin menghitung peluang, mean, variance, dan quantile, - pendekatan numerik lebih realistis daripada memaksakan model yang belum tentu cocok.

== 4.3 Uniform Kontinu
<uniform-kontinu>
=== K --- Konteks
<k-konteks-20>
Distribusi uniform kontinu cocok ketika nilai dianggap tersebar merata pada sebuah interval. Misalnya: - waktu kedatangan acak di antara dua titik waktu, - lokasi acak pada segmen garis, - nilai acak yang dipilih secara merata dari suatu rentang.

=== M --- Model
<m-model-20>
Jika: $ X tilde.op upright(U n i f o r m) \( a \, b \) $ maka PDF-nya:

$ f \( x \) = frac(1, b - a) \, #h(2em) a lt.eq x lt.eq b $

dan nol di luar interval tersebut.

=== Q --- Questions
<q-questions-20>
+ Berapa peluang $X$ berada pada sub-interval tertentu?
+ Berapa mean dan variance?
+ Kapan asumsi “semua nilai di interval sama padat” masuk akal?

=== A --- Apply
<a-apply-20>
#Skylighting(([#NormalTok("a, b ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#DecValTok("8");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("400");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" np.where((x ");#OperatorTok(">=");#NormalTok(" a) ");#OperatorTok("&");#NormalTok(" (x ");#OperatorTok("<=");#NormalTok(" b), ");#DecValTok("1");#OperatorTok("/");#NormalTok("(b");#OperatorTok("-");#NormalTok("a), ");#FloatTok("0.0");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.fill_between(x, ");#DecValTok("0");#NormalTok(", pdf, where");#OperatorTok("=");#NormalTok("((x ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("3");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (x ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("5");#NormalTok(")), alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF Uniform(2,8)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-7-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(3 <= X <= 5) =\"");#NormalTok(", (");#DecValTok("5");#OperatorTok("-");#DecValTok("3");#NormalTok(")");#OperatorTok("/");#NormalTok("(");#DecValTok("8");#OperatorTok("-");#DecValTok("2");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", (a");#OperatorTok("+");#NormalTok("b)");#OperatorTok("/");#DecValTok("2");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance =\"");#NormalTok(", (b");#OperatorTok("-");#NormalTok("a)");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("/");#NormalTok(" ");#DecValTok("12");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("P(3 <= X <= 5) = 0.3333333333333333");],
[#NormalTok("Mean = 5.0");],
[#NormalTok("Variance = 3.0");],));
]
]
==== Hasil teoritis
<hasil-teoritis-5>
$ E \[ X \] = frac(a + b, 2) $

$ upright(V a r) \( X \) = frac(\( b - a \)^2, 12) $

=== Latihan singkat
<latihan-singkat-11>
+ Jika $X tilde.op upright(U n i f o r m) \( 10 \, 20 \)$, hitung $P \( 12 lt.eq X lt.eq 15 \)$.
+ Hitung mean dan variance-nya.
+ Beri satu contoh aplikasi nyata yang cocok dimodelkan uniform kontinu.

== 4.4 Normal Distribution
<normal-distribution>
=== K --- Konteks
<k-konteks-21>
Normal adalah salah satu distribusi paling terkenal karena sering muncul pada: - error pengukuran, - tinggi badan, - berat badan, - hasil agregasi banyak pengaruh kecil, - noise sensor.

=== M --- Model
<m-model-21>
Jika: $ X tilde.op cal(N) \( mu \, sigma^2 \) $ maka PDF-nya:

$ f \( x \) = frac(1, sigma sqrt(2 pi)) exp (- frac(\( x - mu \)^2, 2 sigma^2)) $

Parameter: - $mu$: pusat distribusi, - $sigma$: skala penyebaran.

=== Q --- Questions
<q-questions-21>
+ Berapa peluang $X$ kurang dari nilai tertentu?
+ Berapa peluang $X$ berada dalam interval tertentu?
+ Bagaimana pengaruh $mu$ dan $sigma$ pada bentuk kurva?

=== A --- Apply
<a-apply-21>
#Skylighting(([#NormalTok("mu, sigma ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");#NormalTok(", ");#DecValTok("15");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("40");#NormalTok(", ");#DecValTok("160");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.norm.pdf(x, loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF Normal(100, 15^2)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-9-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X < 90) =\"");#NormalTok(", stats.norm.cdf(");#DecValTok("90");#NormalTok(", loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(90 <= X <= 110) =\"");#NormalTok(", stats.norm.cdf(");#DecValTok("110");#NormalTok(", loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma) ");#OperatorTok("-");#NormalTok(" stats.norm.cdf(");#DecValTok("90");#NormalTok(", loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma))");],));
#block[
#Skylighting(([#NormalTok("P(X < 90) = 0.2524925375469229");],
[#NormalTok("P(90 <= X <= 110) = 0.4950149249061542");],));
]
]
==== Hubungan dengan Binomial
<hubungan-dengan-binomial>
Jika: - $X tilde.op upright(B i n o m i a l) \( n \, p \)$, - $n$ besar,

maka Binomial dapat didekati oleh Normal dengan:

$ mu = n p \, #h(2em) sigma^2 = n p \( 1 - p \) $

Mari lihat contoh.

#Skylighting(([#NormalTok("n, p ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");#NormalTok(", ");#FloatTok("0.4");],
[#NormalTok("mu_bin ");#OperatorTok("=");#NormalTok(" n");#OperatorTok("*");#NormalTok("p");],
[#NormalTok("sigma_bin ");#OperatorTok("=");#NormalTok(" np.sqrt(n");#OperatorTok("*");#NormalTok("p");#OperatorTok("*");#NormalTok("(");#DecValTok("1");#OperatorTok("-");#NormalTok("p))");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("20");#NormalTok(", ");#DecValTok("61");#NormalTok(")");],
[#NormalTok("pmf_bin ");#OperatorTok("=");#NormalTok(" stats.binom.pmf(x, n");#OperatorTok("=");#NormalTok("n, p");#OperatorTok("=");#NormalTok("p)");],
[],
[#NormalTok("x_cont ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("20");#NormalTok(", ");#DecValTok("60");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[#NormalTok("pdf_norm ");#OperatorTok("=");#NormalTok(" stats.norm.pdf(x_cont, loc");#OperatorTok("=");#NormalTok("mu_bin, scale");#OperatorTok("=");#NormalTok("sigma_bin)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.stem(x, pmf_bin, basefmt");#OperatorTok("=");#StringTok("\" \"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Binomial\"");#NormalTok(")");],
[#NormalTok("plt.plot(x_cont, pdf_norm, ");#StringTok("'r'");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Normal approximation\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Probability / Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Pendekatan Normal terhadap Binomial\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-11-output-1.svg"))

==== Interpretasi keputusan
<interpretasi-keputusan-6>
Normal sering dipakai untuk: - menetapkan toleransi manufaktur, - menghitung peluang deviasi pengukuran, - mengevaluasi performa relatif terhadap target.

=== Latihan singkat
<latihan-singkat-12>
+ Jika $X tilde.op cal(N) \( 70 \, 10^2 \)$, hitung $P \( X < 60 \)$.
+ Hitung $P \( 65 lt.eq X lt.eq 80 \)$.
+ Simulasikan 10000 sampel dari distribusi ini dan bandingkan histogram dengan PDF.

== 4.5 Gamma Distribution
<gamma-distribution>
=== K --- Konteks
<k-konteks-22>
Distribusi Gamma sangat berguna untuk memodelkan: - waktu tunggu sampai beberapa kejadian terjadi, - lifetime positif dengan bentuk fleksibel, - akumulasi beberapa waktu tunggu eksponensial.

=== M --- Model
<m-model-22>
Salah satu parametrisasinya: $ X tilde.op upright(G a m m a) \( alpha \, theta \) $

dengan: - $alpha$ = shape, - $theta$ = scale.

PDF-nya:

$ f \( x \) = frac(1, Gamma \( alpha \) theta^alpha) x^(alpha - 1) e^(- x \/ theta) \, #h(2em) x > 0 $

=== Q --- Questions
<q-questions-22>
+ Apa pengaruh shape dan scale?
+ Kapan Gamma lebih cocok daripada Exponential?
+ Bagaimana menghitung peluang waktu selesai sebelum batas tertentu?

=== A --- Apply
<a-apply-22>
#Skylighting(([#NormalTok("alpha, theta ");#OperatorTok("=");#NormalTok(" ");#DecValTok("3");#NormalTok(", ");#DecValTok("2");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("30");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.gamma.pdf(x, a");#OperatorTok("=");#NormalTok("alpha, scale");#OperatorTok("=");#NormalTok("theta)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF Gamma(shape=3, scale=2)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-12-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", alpha ");#OperatorTok("*");#NormalTok(" theta)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance =\"");#NormalTok(", alpha ");#OperatorTok("*");#NormalTok(" theta");#OperatorTok("**");#DecValTok("2");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X <= 8) =\"");#NormalTok(", stats.gamma.cdf(");#DecValTok("8");#NormalTok(", a");#OperatorTok("=");#NormalTok("alpha, scale");#OperatorTok("=");#NormalTok("theta))");],));
#block[
#Skylighting(([#NormalTok("Mean = 6");],
[#NormalTok("Variance = 12");],
[#NormalTok("P(X <= 8) = 0.7618966944464556");],));
]
]
==== Hasil teoritis
<hasil-teoritis-6>
$ E \[ X \] = alpha theta $

$ upright(V a r) \( X \) = alpha theta^2 $

=== Interpretasi
<interpretasi-11>
Gamma cocok untuk waktu positif yang tidak memoryless dan memiliki bentuk yang bisa semakin “membukit” saat shape membesar.

== 4.6 Exponential Distribution
<exponential-distribution>
=== K --- Konteks
<k-konteks-23>
Distribusi Exponential sangat terkenal untuk memodelkan: - waktu antar kedatangan pada Poisson process, - waktu sampai kegagalan pertama pada sistem memoryless, - waktu tunggu hingga kejadian berikutnya.

=== M --- Model
<m-model-23>
Jika: $ X tilde.op upright(E x p o n e n t i a l) \( lambda \) $ maka PDF-nya:

$ f \( x \) = lambda e^(- lambda x) \, #h(2em) x gt.eq 0 $

CDF-nya:

$ F \( x \) = 1 - e^(- lambda x) $

=== Q --- Questions
<q-questions-23>
+ Berapa peluang menunggu kurang dari $t$?
+ Mengapa distribusi ini memoryless?
+ Bagaimana hubungannya dengan Poisson process?

=== A --- Apply
<a-apply-23>
#Skylighting(([#NormalTok("lam ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.5");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("15");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.expon.pdf(x, scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF Exponential(rate=0.5)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-14-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", ");#DecValTok("1");#OperatorTok("/");#NormalTok("lam)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance =\"");#NormalTok(", ");#DecValTok("1");#OperatorTok("/");#NormalTok("lam");#OperatorTok("**");#DecValTok("2");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X <= 3) =\"");#NormalTok(", stats.expon.cdf(");#DecValTok("3");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X > 5) =\"");#NormalTok(", ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" stats.expon.cdf(");#DecValTok("5");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam))");],));
#block[
#Skylighting(([#NormalTok("Mean = 2.0");],
[#NormalTok("Variance = 4.0");],
[#NormalTok("P(X <= 3) = 0.7768698398515702");],
[#NormalTok("P(X > 5) = 0.08208499862389884");],));
]
]
==== Sifat memoryless
<sifat-memoryless-1>
$ P \( X > s + t divides X > s \) = P \( X > t \) $

Distribusi Exponential adalah versi kontinu dari ide memoryless yang di dunia diskrit dimiliki distribusi Geometric.

==== Hubungan dengan Poisson process
<hubungan-dengan-poisson-process>
Jika jumlah kejadian per interval mengikuti Poisson process dengan rate $lambda$, maka waktu antar kedatangan mengikuti Exponential($lambda$).

Mari simulasikan.

#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("123");#NormalTok(")");],
[#NormalTok("lam ");#OperatorTok("=");#NormalTok(" ");#FloatTok("2.0");#NormalTok("  ");#CommentTok("## rata-rata 2 kejadian per satuan waktu");],
[],
[#NormalTok("interarrival ");#OperatorTok("=");#NormalTok(" rng.exponential(scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam, size");#OperatorTok("=");#DecValTok("50000");#NormalTok(")");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", np.percentile(interarrival, ");#FloatTok("99.5");#NormalTok("), ");#DecValTok("400");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.expon.pdf(x, scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(interarrival, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Simulasi\"");#NormalTok(")");],
[#NormalTok("plt.plot(x, pdf, label");#OperatorTok("=");#StringTok("\"PDF teoritis\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Interarrival time\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Interarrival time pada Poisson process ~ Exponential\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-16-output-1.svg"))

=== Latihan singkat
<latihan-singkat-13>
+ Jika rata-rata waktu tunggu 10 menit, berapa rate $lambda$?
+ Hitung peluang waktu tunggu kurang dari 5 menit.
+ Verifikasi sifat memoryless dengan simulasi.

== 4.7 Erlang Distribution
<erlang-distribution>
=== K --- Konteks
<k-konteks-24>
Erlang muncul ketika kita menjumlahkan beberapa waktu tunggu Eksponensial independen dengan rate yang sama. Misalnya: - total waktu layanan yang melewati beberapa tahap berurutan, - waktu sampai $k$ kejadian dalam Poisson process.

=== M --- Model
<m-model-24>
Jika: $ X = X_1 + X_2 + dots.h.c + X_k $ dengan tiap $X_i tilde.op upright("Exponential") \( lambda \)$ independen, maka:

$ X tilde.op upright("Erlang") \( k \, lambda \) $

Erlang adalah kasus khusus Gamma dengan shape integer.

=== Q --- Questions
<q-questions-24>
+ Bagaimana bentuk distribusinya dibanding Exponential?
+ Bagaimana pengaruh $k$?
+ Apa arti praktis “jumlah beberapa tahap layanan”?

=== A --- Apply
<a-apply-24>
#Skylighting(([#NormalTok("lam ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.5");],
[#NormalTok("k ");#OperatorTok("=");#NormalTok(" ");#DecValTok("3");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("25");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.gamma.pdf(x, a");#OperatorTok("=");#NormalTok("k, scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF Erlang(k=3, rate=0.5)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-17-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", k");#OperatorTok("/");#NormalTok("lam)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance =\"");#NormalTok(", k");#OperatorTok("/");#NormalTok("(lam");#OperatorTok("**");#DecValTok("2");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X <= 8) =\"");#NormalTok(", stats.gamma.cdf(");#DecValTok("8");#NormalTok(", a");#OperatorTok("=");#NormalTok("k, scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam))");],));
#block[
#Skylighting(([#NormalTok("Mean = 6.0");],
[#NormalTok("Variance = 12.0");],
[#NormalTok("P(X <= 8) = 0.7618966944464556");],));
]
]
==== Interpretasi
<interpretasi-12>
Jika suatu proses terdiri dari 3 tahap memoryless independen, maka total waktunya tidak lagi Exponential, tetapi Erlang-3.

== 4.8 Weibull Distribution
<weibull-distribution>
=== K --- Konteks
<k-konteks-25>
Weibull sangat populer dalam reliability engineering karena dapat memodelkan berbagai pola kegagalan: - kegagalan awal, - kegagalan acak, - kegagalan akibat keausan.

=== M --- Model
<m-model-25>
Jika: $ X tilde.op upright("Weibull") \( k \, lambda \) $ dengan: - $k$ = shape, - $lambda$ = scale,

maka PDF-nya adalah:

$ f \( x \) = k / lambda (x / lambda)^(k - 1) e^(- \( x \/ lambda \)^k) \, #h(2em) x gt.eq 0 $

=== Q --- Questions
<q-questions-25>
+ Bagaimana shape $k$ memengaruhi hazard?
+ Kapan Weibull lebih realistis daripada Exponential?
+ Bagaimana peluang komponen gagal sebelum waktu tertentu?

=== A --- Apply
<a-apply-25>
#Skylighting(([#NormalTok("k_shape ");#OperatorTok("=");#NormalTok(" ");#FloatTok("2.0");],
[#NormalTok("lam_scale ");#OperatorTok("=");#NormalTok(" ");#FloatTok("10.0");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("30");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.weibull_min.pdf(x, c");#OperatorTok("=");#NormalTok("k_shape, scale");#OperatorTok("=");#NormalTok("lam_scale)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF Weibull(shape=2, scale=10)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-19-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X <= 8) =\"");#NormalTok(", stats.weibull_min.cdf(");#DecValTok("8");#NormalTok(", c");#OperatorTok("=");#NormalTok("k_shape, scale");#OperatorTok("=");#NormalTok("lam_scale))");],));
#block[
#Skylighting(([#NormalTok("P(X <= 8) = 0.47270757595695145");],));
]
]
==== Interpretasi
<interpretasi-13>
Weibull lebih fleksibel daripada Exponential. Ia sangat berguna saat laju kegagalan tidak konstan.

== 4.9 Pareto Distribution
<pareto-distribution>
=== K --- Konteks
<k-konteks-26>
Pareto dipakai untuk fenomena heavy-tail, misalnya: - kekayaan, - ukuran file, - kerugian ekstrem, - pendapatan segelintir pihak yang sangat besar.

=== M --- Model
<m-model-26>
Jika: $ X tilde.op upright("Pareto") \( x_m \, alpha \) $ maka untuk $x gt.eq x_m$:

$ f \( x \) = alpha x_m^alpha / x^(alpha + 1) $

=== Q --- Questions
<q-questions-26>
+ Mengapa Pareto menghasilkan peluang ekstrem yang lebih besar?
+ Kapan model heavy-tail penting dalam keputusan?
+ Mengapa mean/variance bisa bermasalah untuk parameter tertentu?

=== A --- Apply
<a-apply-26>
#Skylighting(([#NormalTok("alpha ");#OperatorTok("=");#NormalTok(" ");#FloatTok("3.0");],
[#NormalTok("xm ");#OperatorTok("=");#NormalTok(" ");#FloatTok("1.0");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("1");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.pareto.pdf(x, b");#OperatorTok("=");#NormalTok("alpha, scale");#OperatorTok("=");#NormalTok("xm)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF Pareto\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-21-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X > 3) =\"");#NormalTok(", ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" stats.pareto.cdf(");#DecValTok("3");#NormalTok(", b");#OperatorTok("=");#NormalTok("alpha, scale");#OperatorTok("=");#NormalTok("xm))");],));
#block[
#Skylighting(([#NormalTok("P(X > 3) = 0.03703703703703698");],));
]
]
==== Interpretasi
<interpretasi-14>
Pareto penting ketika kejadian ekstrem tidak boleh diabaikan. Dalam pengambilan keputusan risiko, tail tebal bisa sangat menentukan.

== 4.10 Chi-Square Distribution
<chi-square-distribution>
=== K --- Konteks
<k-konteks-27>
Chi-Square muncul dalam: - inferensi statistik, - goodness-of-fit, - analisis varians, - penjumlahan kuadrat peubah normal baku.

=== M --- Model
<m-model-27>
Jika: $ Z_1 \, Z_2 \, dots.h \, Z_k tilde.op cal(N) \( 0 \, 1 \) $ independen, maka:

$ X = Z_1^2 + Z_2^2 + dots.h.c + Z_k^2 tilde.op chi^2 \( k \) $

Distribusi ini adalah kasus khusus Gamma.

=== Q --- Questions
<q-questions-27>
+ Mengapa bentuknya hanya pada nilai non-negatif?
+ Apa hubungan Chi-Square dengan Normal?
+ Mengapa distribusi ini penting di statistika?

=== A --- Apply
<a-apply-27>
#Skylighting(([#NormalTok("df ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("20");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.chi2.pdf(x, df");#OperatorTok("=");#NormalTok("df)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(x, pdf)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"f(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"PDF Chi-Square(df=5)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-23-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean =\"");#NormalTok(", df)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Variance =\"");#NormalTok(", ");#DecValTok("2");#OperatorTok("*");#NormalTok("df)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X <= 7) =\"");#NormalTok(", stats.chi2.cdf(");#DecValTok("7");#NormalTok(", df");#OperatorTok("=");#NormalTok("df))");],));
#block[
#Skylighting(([#NormalTok("Mean = 5");],
[#NormalTok("Variance = 10");],
[#NormalTok("P(X <= 7) = 0.7793596920632894");],));
]
]
== 4.11 Hubungan Antardistribusi
<hubungan-antardistribusi>
Bagian ini penting karena membantu mahasiswa melihat probabilitas sebagai jaringan ide, bukan daftar rumus terpisah.

=== Exponential ↔ Poisson Process
<exponential-poisson-process>
Jika banyak kejadian dalam interval mengikuti Poisson process dengan rate $lambda$, maka waktu antar kedatangan mengikuti Exponential($lambda$).

=== Erlang ↔ Exponential
<erlang-exponential>
Erlang adalah jumlah beberapa random variable Exponential independen dengan rate sama.

=== Gamma ↔ Erlang
<gamma-erlang>
Erlang adalah kasus khusus Gamma dengan parameter shape berupa bilangan bulat positif.

=== Normal ↔ Binomial
<normal-binomial>
Binomial dengan $n$ besar sering dapat didekati oleh Normal.

=== Chi-Square ↔ Gamma
<chi-square-gamma>
Chi-Square adalah kasus khusus Gamma.

Mari buat diagram singkat dengan Mermaid.

#Skylighting(([#NormalTok("flowchart LR");],
[#NormalTok("    PoissonProcess[\"Poisson Process\"] --> Exponential[\"Exponential (interarrival time)\"]");],
[#NormalTok("    Exponential --> Erlang[\"Erlang = jumlah k Exponential iid\"]");],
[#NormalTok("    Erlang --> Gamma[\"Gamma (generalisasi Erlang)\"]");],
[#NormalTok("    Binomial[\"Binomial (n besar)\"] --> Normal[\"Normal approximation\"]");],
[#NormalTok("    Gamma --> ChiSquare[\"Chi-Square (kasus khusus Gamma)\"]");],));
#block[

#block[
#box(image("04-distribusi-kontinu_files\\figure-typst\\mermaid-figure-1.png", height: 2.06in, width: 15.07in))

]

]
== 4.12 Mini-Case KMQA 1 --- Garansi Produk
<mini-case-kmqa-1-garansi-produk>
=== K --- Konteks
<k-konteks-28>
Umur hidup lampu memengaruhi kebijakan garansi. Jika garansi terlalu panjang, biaya klaim meningkat. Jika terlalu pendek, pelanggan kecewa.

=== M --- Model
<m-model-28>
Misalkan umur hidup $X tilde.op cal(N) \( 900 \, 50^2 \)$.

=== Q --- Questions
<q-questions-28>
+ Berapa peluang rusak sebelum 800 jam?
+ Berapa jika garansi 850 atau 900 jam?
+ Kebijakan mana yang lebih konservatif?

=== A --- Apply
<a-apply-28>
#block[
#Skylighting(([#NormalTok("mu, sigma ");#OperatorTok("=");#NormalTok(" ");#DecValTok("900");#NormalTok(", ");#DecValTok("50");],
[#ControlFlowTok("for");#NormalTok(" T ");#KeywordTok("in");#NormalTok(" [");#DecValTok("800");#NormalTok(", ");#DecValTok("850");#NormalTok(", ");#DecValTok("900");#NormalTok("]:");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P(X < ");#SpecialCharTok("{");#NormalTok("T");#SpecialCharTok("}");#SpecialStringTok(") =\"");#NormalTok(", stats.norm.cdf(T, loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma))");],));
#block[
#Skylighting(([#NormalTok("P(X < 800) = 0.0227501319481792");],
[#NormalTok("P(X < 850) = 0.15865525393145707");],
[#NormalTok("P(X < 900) = 0.5");],));
]
]
==== Interpretasi
<interpretasi-15>
CDF langsung memberi estimasi proporsi klaim garansi.

== 4.13 Mini-Case KMQA 2 --- Waktu Antar Kedatangan Pasien
<mini-case-kmqa-2-waktu-antar-kedatangan-pasien>
=== K --- Konteks
<k-konteks-29>
Sebuah klinik menerima pasien secara acak. Kita ingin memodelkan selang waktu antar kedatangan.

=== M --- Model
<m-model-29>
Jika kedatangan mengikuti Poisson process dengan rate $lambda$, maka interarrival time: $ X tilde.op upright(E x p o n e n t i a l) \( lambda \) $

=== Q --- Questions
<q-questions-29>
+ Berapa peluang pasien berikut datang dalam 10 menit?
+ Berapa rata-rata selang tunggu?

=== A --- Apply
<a-apply-29>
#block[
#Skylighting(([#CommentTok("## rate 2 pasien/jam => 1 pasien setiap 30 menit rata-rata");],
[#NormalTok("lam_per_hour ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");],
[#NormalTok("lam_per_minute ");#OperatorTok("=");#NormalTok(" lam_per_hour ");#OperatorTok("/");#NormalTok(" ");#DecValTok("60");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rata-rata waktu tunggu (menit) =\"");#NormalTok(", ");#DecValTok("1");#OperatorTok("/");#NormalTok("lam_per_minute)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(datang dalam 10 menit) =\"");#NormalTok(", stats.expon.cdf(");#DecValTok("10");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam_per_minute))");],));
#block[
#Skylighting(([#NormalTok("Rata-rata waktu tunggu (menit) = 30.0");],
[#NormalTok("P(datang dalam 10 menit) = 0.28346868942621073");],));
]
]
== 4.14 Mini-Case KMQA 3 --- Tiga Sub-Layanan Berantai
<mini-case-kmqa-3-tiga-sub-layanan-berantai>
=== K --- Konteks
<k-konteks-30>
Sebuah layanan terdiri dari tiga tahap berurutan, masing-masing memoryless dan independen.

=== M --- Model
<m-model-30>
Masing-masing tahap $X_i tilde.op upright(E x p o n e n t i a l) \( lambda \)$, maka total: $ T = X_1 + X_2 + X_3 tilde.op upright("Erlang") \( 3 \, lambda \) $

=== Q --- Questions
<q-questions-30>
+ Berapa mean total durasi?
+ Mengapa totalnya tidak lagi Exponential?
+ Bagaimana histogram Monte Carlo dibanding PDF Erlang?

=== A --- Apply
<a-apply-30>
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("42");#NormalTok(")");],
[#NormalTok("lam ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.5");],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100000");],
[],
[#NormalTok("X1 ");#OperatorTok("=");#NormalTok(" rng.exponential(scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam, size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("X2 ");#OperatorTok("=");#NormalTok(" rng.exponential(scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam, size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("X3 ");#OperatorTok("=");#NormalTok(" rng.exponential(scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam, size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("T ");#OperatorTok("=");#NormalTok(" X1 ");#OperatorTok("+");#NormalTok(" X2 ");#OperatorTok("+");#NormalTok(" X3");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", np.percentile(T, ");#FloatTok("99.5");#NormalTok("), ");#DecValTok("400");#NormalTok(")");],
[#NormalTok("pdf ");#OperatorTok("=");#NormalTok(" stats.gamma.pdf(x, a");#OperatorTok("=");#DecValTok("3");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#OperatorTok("/");#NormalTok("lam)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(T, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Monte Carlo\"");#NormalTok(")");],
[#NormalTok("plt.plot(x, pdf, label");#OperatorTok("=");#StringTok("\"PDF Erlang-3\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Durasi total\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Jumlah 3 Exponential iid menghasilkan Erlang-3\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("04-distribusi-kontinu_files/figure-typst/cell-27-output-1.svg"))

== 4.15 Python Toolbox untuk Distribusi Kontinu
<python-toolbox-untuk-distribusi-kontinu>
#block[
#Skylighting(([#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],));
]
=== Normal
<normal>
#Skylighting(([#NormalTok("stats.norm.pdf(");#DecValTok("0");#NormalTok(", loc");#OperatorTok("=");#DecValTok("0");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#NormalTok("), stats.norm.cdf(");#FloatTok("1.96");#NormalTok(", loc");#OperatorTok("=");#DecValTok("0");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],));
#Skylighting(([#NormalTok("(np.float64(0.3989422804014327), np.float64(0.9750021048517795))");],));
=== Exponential
<exponential>
#Skylighting(([#NormalTok("stats.expon.pdf(");#DecValTok("2");#NormalTok(", scale");#OperatorTok("=");#DecValTok("3");#NormalTok("), stats.expon.cdf(");#DecValTok("2");#NormalTok(", scale");#OperatorTok("=");#DecValTok("3");#NormalTok(")");],));
#Skylighting(([#NormalTok("(np.float64(0.17113903967753066), np.float64(0.486582880967408))");],));
=== Gamma
<gamma>
#Skylighting(([#NormalTok("stats.gamma.pdf(");#DecValTok("4");#NormalTok(", a");#OperatorTok("=");#DecValTok("3");#NormalTok(", scale");#OperatorTok("=");#DecValTok("2");#NormalTok("), stats.gamma.cdf(");#DecValTok("4");#NormalTok(", a");#OperatorTok("=");#DecValTok("3");#NormalTok(", scale");#OperatorTok("=");#DecValTok("2");#NormalTok(")");],));
#Skylighting(([#NormalTok("(np.float64(0.1353352832366127), np.float64(0.32332358381693654))");],));
=== Weibull
<weibull>
#Skylighting(([#NormalTok("stats.weibull_min.pdf(");#DecValTok("4");#NormalTok(", c");#OperatorTok("=");#DecValTok("2");#NormalTok(", scale");#OperatorTok("=");#DecValTok("10");#NormalTok("), stats.weibull_min.cdf(");#DecValTok("4");#NormalTok(", c");#OperatorTok("=");#DecValTok("2");#NormalTok(", scale");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
#Skylighting(([#NormalTok("(np.float64(0.06817150311729692), np.float64(0.14785621103378868))");],));
=== Pareto
<pareto>
#Skylighting(([#NormalTok("stats.pareto.pdf(");#DecValTok("2");#NormalTok(", b");#OperatorTok("=");#DecValTok("3");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#NormalTok("), stats.pareto.cdf(");#DecValTok("2");#NormalTok(", b");#OperatorTok("=");#DecValTok("3");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],));
#Skylighting(([#NormalTok("(np.float64(0.1875), np.float64(0.875))");],));
=== Chi-Square
<chi-square>
#Skylighting(([#NormalTok("stats.chi2.pdf(");#DecValTok("5");#NormalTok(", df");#OperatorTok("=");#DecValTok("4");#NormalTok("), stats.chi2.cdf(");#DecValTok("5");#NormalTok(", df");#OperatorTok("=");#DecValTok("4");#NormalTok(")");],));
#Skylighting(([#NormalTok("(np.float64(0.10260624827987348), np.float64(0.7127025048163542))");],));
== 4.16 Kesalahan Umum yang Harus Dihindari
<kesalahan-umum-yang-harus-dihindari-1>
+ #strong[Menganggap tinggi PDF adalah peluang] \
  Tidak. Peluang adalah area di bawah kurva.

+ #strong[Menghitung $P \( X = x \)$ untuk kontinu seolah-olah positif] \
  Dalam model kontinu, peluang titik tunggal adalah nol.

+ #strong[Memakai Exponential untuk semua lifetime] \
  Exponential hanya cocok bila hazard rate konstan / memoryless.

+ #strong[Memakai Normal untuk data yang sangat skewed atau bernilai negatif-padahal tidak mungkin] \
  Pilih model sesuai konteks.

+ #strong[Menghafal distribusi tanpa memahami makna parameter] \
  Yang penting bukan sekadar nama distribusinya, tetapi arti shape, scale, mean, variance, dan implikasinya.

== 4.17 Menyimpulkan Bab Ini
<menyimpulkan-bab-ini-3>
Distribusi kontinu memberi kita bahasa untuk memodelkan banyak besaran dunia nyata yang berupa pengukuran, waktu, umur hidup, dan nilai-nilai positif yang berubah halus.

Kita telah melihat: - #strong[uniform kontinu] untuk interval yang merata, - #strong[normal] untuk fenomena simetris dan agregatif, - #strong[gamma] untuk waktu tunggu positif yang fleksibel, - #strong[exponential] untuk memoryless waiting time, - #strong[erlang] untuk jumlah beberapa exponential, - #strong[weibull] untuk reliability yang lebih fleksibel, - #strong[pareto] untuk heavy-tail, - #strong[chi-square] untuk inferensi statistik dan hubungan dengan normal.

Di samping itu, hubungan antardistribusi membantu kita melihat probabilitas sebagai sistem ide yang saling terhubung.

== 4.18 Ringkasan Poin Inti
<ringkasan-poin-inti-3>
+ Untuk random variable kontinu, peluang diperoleh dari #strong[area] di bawah PDF.
+ Distribusi kontinu kustom bisa dibangun dari tabel atau interpolasi numerik.
+ #strong[Uniform kontinu] cocok untuk interval merata.
+ #strong[Normal] penting untuk banyak fenomena simetris dan sebagai pendekatan Binomial.
+ #strong[Exponential] memodelkan waiting time memoryless dan terkait erat dengan Poisson process.
+ #strong[Gamma] dan #strong[Erlang] memodelkan akumulasi waiting time.
+ #strong[Weibull] sangat penting dalam reliability engineering.
+ #strong[Pareto] penting untuk fenomena ekstrem dan heavy-tail.
+ #strong[Chi-Square] adalah distribusi penting dalam statistika inferensial.
+ Memahami hubungan antardistribusi membantu membangun intuisi yang lebih dalam.

== 4.19 Latihan Bab 4
<latihan-bab-4>
=== A. Konseptual
<a.-konseptual-3>
+ Mengapa peluang titik tunggal pada RV kontinu bernilai nol?
+ Apa perbedaan utama antara PDF dan CDF?
+ Mengapa Exponential disebut memoryless?
+ Mengapa Weibull sering lebih realistis daripada Exponential untuk data kegagalan?

=== B. Hitungan
<b.-hitungan-2>
+ Jika $X tilde.op upright(U n i f o r m) \( 2 \, 8 \)$, hitung $P \( 3 lt.eq X lt.eq 5 \)$.
+ Jika $X tilde.op cal(N) \( 100 \, 15^2 \)$, hitung $P \( X < 90 \)$.
+ Jika $X tilde.op upright(E x p o n e n t i a l) \( lambda = 0.5 \)$, hitung $P \( X lt.eq 3 \)$.
+ Jika $X tilde.op upright(G a m m a) \( 3 \, 2 \)$, hitung $E \[ X \]$ dan $upright(V a r) \( X \)$.

=== C. Python
<c.-python-2>
+ Simulasikan 10000 sampel Uniform(0,1) dan bandingkan histogram dengan PDF.
+ Simulasikan Normal dan bandingkan histogram dengan PDF.
+ Simulasikan interarrival time Poisson process dan bandingkan dengan Exponential teoritis.
+ Simulasikan jumlah tiga Exponential dan bandingkan dengan Erlang teoritis.

=== D. Aplikatif
<d.-aplikatif-2>
+ Pilih model yang paling cocok untuk:
  - tinggi badan,
  - waktu antar kedatangan pelanggan,
  - lifetime komponen dengan keausan,
  - kerugian ekstrem.
+ Jelaskan alasan pemilihan model tersebut.
+ Dalam kasus garansi produk, ukuran apa yang paling penting: mean umur, variance umur, atau peluang rusak sebelum T?

== 4.20 Penutup Kecil
<penutup-kecil-3>
Kalau bab sebelumnya mengajarkan kita menghitung kejadian yang berupa hitungan, maka bab ini mengajarkan kita berpikir tentang besaran yang mengalir: waktu, umur hidup, pengukuran, dan intensitas.

Di bab berikutnya, kita akan memperluas pandangan lagi: dunia nyata jarang hanya punya satu peubah acak. Kita akan mulai melihat #strong[lebih dari satu random variable sekaligus], hubungan di antaranya, serta apa yang terjadi ketika satu random variable menjadi fungsi dari yang lain.

= Bab 5. Random Variable Multivariat dan Fungsi Random Variable
<bab-5.-random-variable-multivariat-dan-fungsi-random-variable>
== Tujuan Bab
<tujuan-bab-4>
Setelah mempelajari bab ini, mahasiswa diharapkan mampu:

+ memahami bahwa banyak masalah nyata melibatkan #strong[lebih dari satu random variable],
+ membedakan distribusi #strong[joint], #strong[marginal], dan #strong[conditional],
+ memahami makna #strong[independensi] pada random variable multivariat,
+ menghitung dan menafsirkan #strong[kovariansi] dan #strong[korelasi],
+ memahami bahwa fungsi dari random variable juga merupakan random variable,
+ menggunakan Python untuk simulasi, visualisasi, dan eksplorasi hubungan antar peubah acak,
+ menghubungkan konsep-konsep ini dengan pengambilan keputusan di bidang teknik, bisnis, dan layanan.

== Pembuka
<pembuka-4>
Sampai bab sebelumnya, kita sering berbicara seolah-olah dunia hanya memiliki #strong[satu] random variable pada satu waktu: - jumlah cacat, - waktu tunggu, - umur hidup, - profit, - jumlah pelanggan.

Namun kenyataan jauh lebih kaya. Dalam dunia nyata, keputusan hampir selalu melibatkan #strong[lebih dari satu peubah acak].

Contoh: - tinggi dan berat badan, - permintaan dan pendapatan, - jumlah pelanggan dan waktu layanan, - suhu dan konsumsi listrik, - arus dan daya, - umur komponen dan biaya klaim.

Begitu ada lebih dari satu random variable, muncul pertanyaan-pertanyaan baru: - apakah mereka saling memengaruhi? - apakah keduanya independen? - kalau satu naik, apakah yang lain cenderung naik? - bagaimana distribusi salah satunya bila yang lain diketahui? - bagaimana distribusi output jika output adalah fungsi dari input yang acak?

Bab ini menjawab pertanyaan-pertanyaan itu.

== 5.1 Quick Win: Dua Peubah, Satu Plot
<quick-win-dua-peubah-satu-plot>
Mari mulai dengan simulasi dua random variable yang berkorelasi positif. Misalnya: - $X$ = jam belajar, - $Y$ = skor kuis.

Ini tentu penyederhanaan, tetapi cukup baik untuk melihat ide dasar.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("42");#NormalTok(")");],
[],
[#NormalTok("mean ");#OperatorTok("=");#NormalTok(" [");#DecValTok("5");#NormalTok(", ");#DecValTok("70");#NormalTok("]");],
[#NormalTok("cov ");#OperatorTok("=");#NormalTok(" [[");#FloatTok("1.5");#NormalTok(", ");#DecValTok("8");#NormalTok("],");],
[#NormalTok("       [");#DecValTok("8");#NormalTok(", ");#DecValTok("80");#NormalTok("]]");],
[],
[#NormalTok("data ");#OperatorTok("=");#NormalTok(" rng.multivariate_normal(mean, cov, size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" data[:, ");#DecValTok("0");#NormalTok("]");],
[#NormalTok("Y ");#OperatorTok("=");#NormalTok(" data[:, ");#DecValTok("1");#NormalTok("]");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(",");#DecValTok("5");#NormalTok("))");],
[#NormalTok("plt.scatter(X, Y, alpha");#OperatorTok("=");#FloatTok("0.4");#NormalTok(", s");#OperatorTok("=");#DecValTok("15");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Jam belajar\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Skor kuis\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Dua random variable dengan kecenderungan positif\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-2-output-1.svg"))

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean X =\"");#NormalTok(", X.mean())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean Y =\"");#NormalTok(", Y.mean())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Cov(X,Y) =\"");#NormalTok(", np.cov(X, Y, ddof");#OperatorTok("=");#DecValTok("0");#NormalTok(")[");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("])");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Corr(X,Y) =\"");#NormalTok(", np.corrcoef(X, Y)[");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("])");],));
#block[
#Skylighting(([#NormalTok("Mean X = 5.0966118178007385");],
[#NormalTok("Mean Y = 70.63531660231106");],
[#NormalTok("Cov(X,Y) = 8.268878410266762");],
[#NormalTok("Corr(X,Y) = 0.7409518158857897");],));
]
]
Dari #emph[quick win] ini, kita langsung melihat dua hal: 1. dunia nyata sering lebih masuk akal bila dimodelkan dengan lebih dari satu peubah acak, 2. hubungan antar peubah dapat diringkas dengan konsep seperti #strong[covariance] dan #strong[correlation].

== 5.2 Joint Distribution: Distribusi Bersama
<joint-distribution-distribusi-bersama>
=== K --- Konteks
<k-konteks-31>
Misalkan: - $X$ = jumlah pelanggan datang per jam, - $Y$ = total pendapatan per jam.

Atau: - $X$ = jumlah produk cacat dari supplier A, - $Y$ = jumlah produk cacat dari supplier B.

Kita tidak cukup hanya tahu distribusi $X$ sendiri atau $Y$ sendiri. Kita ingin tahu #strong[bagaimana keduanya muncul bersama].

=== M --- Model
<m-model-31>
Distribusi bersama atau #strong[joint distribution] mendeskripsikan peluang dua random variable secara simultan.

==== Untuk diskrit
<untuk-diskrit-1>
$ p_(X \, Y) \( x \, y \) = P \( X = x \, Y = y \) $

==== Untuk kontinu
<untuk-kontinu-1>
$ f_(X \, Y) \( x \, y \) $

Joint distribution memberi informasi lengkap tentang pasangan $\( X \, Y \)$.

=== Q --- Questions
<q-questions-31>
+ Berapa peluang $X$ dan $Y$ mengambil nilai tertentu secara bersamaan?
+ Apakah nilai besar pada $X$ sering disertai nilai besar pada $Y$?
+ Bagaimana menurunkan distribusi salah satu peubah dari distribusi bersama?

=== A --- Apply (diskrit sederhana)
<a-apply-diskrit-sederhana>
Misalkan dua koin fair dilempar. Definisikan: - $X$ = jumlah Head, - $Y$ = indikator apakah koin pertama Head (1) atau tidak (0).

Mari bangun joint distribution-nya.

#Skylighting(([#ImportTok("import");#NormalTok(" itertools");],
[],
[#NormalTok("outcomes ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("list");#NormalTok("(itertools.product([");#StringTok("'H'");#NormalTok(", ");#StringTok("'T'");#NormalTok("], repeat");#OperatorTok("=");#DecValTok("2");#NormalTok("))");],
[],
[#KeywordTok("def");#NormalTok(" X_fun(o):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" o.count(");#StringTok("'H'");#NormalTok(")");],
[],
[#KeywordTok("def");#NormalTok(" Y_fun(o):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#ControlFlowTok("if");#NormalTok(" o[");#DecValTok("0");#NormalTok("] ");#OperatorTok("==");#NormalTok(" ");#StringTok("'H'");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#DecValTok("0");],
[],
[#NormalTok("pairs ");#OperatorTok("=");#NormalTok(" [(X_fun(o), Y_fun(o)) ");#ControlFlowTok("for");#NormalTok(" o ");#KeywordTok("in");#NormalTok(" outcomes]");],
[#NormalTok("pairs");],));
#Skylighting(([#NormalTok("[(2, 1), (1, 1), (1, 0), (0, 0)]");],));
#Skylighting(([#ImportTok("from");#NormalTok(" collections ");#ImportTok("import");#NormalTok(" Counter");],
[],
[#NormalTok("counter ");#OperatorTok("=");#NormalTok(" Counter(pairs)");],
[#NormalTok("joint ");#OperatorTok("=");#NormalTok(" {k: v");#OperatorTok("/");#BuiltInTok("len");#NormalTok("(outcomes) ");#ControlFlowTok("for");#NormalTok(" k,v ");#KeywordTok("in");#NormalTok(" counter.items()}");],
[#NormalTok("joint");],));
#Skylighting(([#NormalTok("{(2, 1): 0.25, (1, 1): 0.25, (1, 0): 0.25, (0, 0): 0.25}");],));
Joint distribution ini memberi peluang bersama, misalnya: $ P \( X = 2 \, Y = 1 \) $

yang berarti: - jumlah Head = 2, - dan koin pertama = Head.

== 5.3 Bivariat Diskrit
<bivariat-diskrit>
Mari buat contoh yang lebih sistematis.

=== Contoh
<contoh>
Misalkan joint PMF didefinisikan sebagai tabel berikut:

$ p_(X \, Y) \( x \, y \) $

dengan $X in { 0 \, 1 \, 2 }$ dan $Y in { 0 \, 1 }$:

#table(
  columns: 3,
  align: (auto,right,right,),
  table.header([$x without y$], [0], [1],),
  table.hline(),
  [0], [0.10], [0.20],
  [1], [0.15], [0.25],
  [2], [0.10], [0.20],
)
Total = 1.

=== Python representation
<python-representation>
#block[
#Skylighting(([#NormalTok("joint_table ");#OperatorTok("=");#NormalTok(" np.array([");],
[#NormalTok("    [");#FloatTok("0.10");#NormalTok(", ");#FloatTok("0.20");#NormalTok("],");],
[#NormalTok("    [");#FloatTok("0.15");#NormalTok(", ");#FloatTok("0.25");#NormalTok("],");],
[#NormalTok("    [");#FloatTok("0.10");#NormalTok(", ");#FloatTok("0.20");#NormalTok("]");],
[#NormalTok("])");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Total probability =\"");#NormalTok(", joint_table.");#BuiltInTok("sum");#NormalTok("())");],));
#block[
#Skylighting(([#NormalTok("Total probability = 1.0");],));
]
]
==== Visualisasi heatmap
<visualisasi-heatmap>
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("5");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.imshow(joint_table, cmap");#OperatorTok("=");#StringTok("'Blues'");#NormalTok(", origin");#OperatorTok("=");#StringTok("'lower'");#NormalTok(")");],
[#NormalTok("plt.colorbar(label");#OperatorTok("=");#StringTok("'Probability'");#NormalTok(")");],
[#NormalTok("plt.xticks([");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("], [");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("])");],
[#NormalTok("plt.yticks([");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok(",");#DecValTok("2");#NormalTok("], [");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok(",");#DecValTok("2");#NormalTok("])");],
[#NormalTok("plt.xlabel(");#StringTok("\"Y\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"X\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Joint PMF bivariat diskrit\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-7-output-1.svg"))

== 5.4 Marginal Distribution
<marginal-distribution>
=== K --- Konteks
<k-konteks-32>
Kadang kita hanya ingin distribusi satu peubah, tanpa memperhatikan peubah lainnya.

=== M --- Model
<m-model-32>
Dari joint distribution, kita bisa memperoleh distribusi #strong[marginal].

==== Untuk diskrit
<untuk-diskrit-2>
$ p_X \( x \) = sum_y p_(X \, Y) \( x \, y \) $

$ p_Y \( y \) = sum_x p_(X \, Y) \( x \, y \) $

=== Q --- Questions
<q-questions-32>
+ Bagaimana “mengabaikan” peubah lain secara formal?
+ Apa arti marginal dalam keputusan?

=== A --- Apply
<a-apply-31>
#block[
#Skylighting(([#NormalTok("pX ");#OperatorTok("=");#NormalTok(" joint_table.");#BuiltInTok("sum");#NormalTok("(axis");#OperatorTok("=");#DecValTok("1");#NormalTok(")  ");#CommentTok("## jumlahkan sepanjang kolom");],
[#NormalTok("pY ");#OperatorTok("=");#NormalTok(" joint_table.");#BuiltInTok("sum");#NormalTok("(axis");#OperatorTok("=");#DecValTok("0");#NormalTok(")  ");#CommentTok("## jumlahkan sepanjang baris");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Marginal pX =\"");#NormalTok(", pX)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Marginal pY =\"");#NormalTok(", pY)");],));
#block[
#Skylighting(([#NormalTok("Marginal pX = [0.3 0.4 0.3]");],
[#NormalTok("Marginal pY = [0.35 0.65]");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("3");#NormalTok("))");],
[],
[#NormalTok("plt.subplot(");#DecValTok("1");#NormalTok(",");#DecValTok("2");#NormalTok(",");#DecValTok("1");#NormalTok(")");],
[#NormalTok("plt.bar([");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok(",");#DecValTok("2");#NormalTok("], pX)");],
[#NormalTok("plt.title(");#StringTok("\"Marginal pX\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"P(X=x)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[],
[#NormalTok("plt.subplot(");#DecValTok("1");#NormalTok(",");#DecValTok("2");#NormalTok(",");#DecValTok("2");#NormalTok(")");],
[#NormalTok("plt.bar([");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("], pY)");],
[#NormalTok("plt.title(");#StringTok("\"Marginal pY\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"y\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"P(Y=y)\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[],
[#NormalTok("plt.tight_layout()");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-9-output-1.svg"))

==== Interpretasi
<interpretasi-16>
Marginal distribution memberi gambaran perilaku satu peubah ketika peubah lain tidak diperhatikan secara eksplisit.

== 5.5 Conditional Distribution
<conditional-distribution>
=== K --- Konteks
<k-konteks-33>
Dalam keputusan nyata, sering kali kita sudah mengetahui sebagian informasi. Misalnya: - distribusi pendapatan per jam #strong[dengan syarat] jumlah pelanggan = 10, - distribusi nilai ujian #strong[dengan syarat] jam belajar \> 5, - distribusi demand #strong[dengan syarat] hari hujan.

=== M --- Model
<m-model-33>
==== Untuk diskrit
<untuk-diskrit-3>
Jika $P \( Y = y \) > 0$, maka:

$ P \( X = x divides Y = y \) = frac(P \( X = x \, Y = y \), P \( Y = y \)) $

=== Q --- Questions
<q-questions-33>
+ Bagaimana distribusi satu peubah berubah jika yang lain diketahui?
+ Mengapa conditional distribution penting untuk inferensi dan keputusan?

=== A --- Apply
<a-apply-32>
Hitung $P \( X = x divides Y = 1 \)$ dari tabel joint sebelumnya.

#block[
#Skylighting(([#CommentTok("## Conditional p(X|Y=1)");],
[#NormalTok("cond_X_given_Y1 ");#OperatorTok("=");#NormalTok(" joint_table[:, ");#DecValTok("1");#NormalTok("] ");#OperatorTok("/");#NormalTok(" pY[");#DecValTok("1");#NormalTok("]");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X=x | Y=1) =\"");#NormalTok(", cond_X_given_Y1)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Jumlah =\"");#NormalTok(", cond_X_given_Y1.");#BuiltInTok("sum");#NormalTok("())");],));
#block[
#Skylighting(([#NormalTok("P(X=x | Y=1) = [0.30769231 0.38461538 0.30769231]");],
[#NormalTok("Jumlah = 1.0");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.bar([");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok(",");#DecValTok("2");#NormalTok("], cond_X_given_Y1)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"P(X=x | Y=1)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Conditional distribution X | Y=1\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-11-output-1.svg"))

==== Interpretasi
<interpretasi-17>
Conditional distribution menunjukkan bahwa ketika informasi tambahan tersedia, distribusi yang relevan untuk keputusan juga berubah.

== 5.6 Independensi
<independensi>
=== K --- Konteks
<k-konteks-34>
Kadang dua peubah tampak tidak saling memengaruhi. Kadang justru sangat terkait. Membedakan dua situasi ini penting.

=== M --- Model
<m-model-34>
Dua random variable $X$ dan $Y$ dikatakan #strong[independen] jika:

==== Untuk diskrit
<untuk-diskrit-4>
$ P \( X = x \, Y = y \) = P \( X = x \) P \( Y = y \) $

untuk semua $x \, y$.

==== Untuk kontinu
<untuk-kontinu-2>
$ f_(X \, Y) \( x \, y \) = f_X \( x \) f_Y \( y \) $

=== Q --- Questions
<q-questions-34>
+ Bagaimana menguji independensi dari joint distribution?
+ Apakah korelasi nol berarti pasti independen?
+ Kapan independensi terlalu kuat sebagai asumsi?

=== A --- Apply
<a-apply-33>
Mari cek apakah joint\_table tadi independen.

#block[
#Skylighting(([#NormalTok("product_table ");#OperatorTok("=");#NormalTok(" np.outer(pX, pY)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Joint table:");#CharTok("\\n");#StringTok("\"");#NormalTok(", joint_table)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"");#CharTok("\\n");#StringTok("Product of marginals:");#CharTok("\\n");#StringTok("\"");#NormalTok(", product_table)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"");#CharTok("\\n");#StringTok("Apakah sama? \"");#NormalTok(", np.allclose(joint_table, product_table))");],));
#block[
#Skylighting(([#NormalTok("Joint table:");],
[#NormalTok(" [[0.1  0.2 ]");],
[#NormalTok(" [0.15 0.25]");],
[#NormalTok(" [0.1  0.2 ]]");],
[],
[#NormalTok("Product of marginals:");],
[#NormalTok(" [[0.105 0.195]");],
[#NormalTok(" [0.14  0.26 ]");],
[#NormalTok(" [0.105 0.195]]");],
[],
[#NormalTok("Apakah sama?  False");],));
]
]
==== Interpretasi
<interpretasi-18>
Jika joint distribution tidak sama dengan hasil kali marginals, maka $X$ dan $Y$ tidak independen.

=== Catatan penting
<catatan-penting-1>
- #strong[Independen ⇒ korelasi nol] (dalam banyak kasus dengan momen terbatas),
- tetapi #strong[korelasi nol tidak selalu berarti independen].

Nanti kita lihat contoh kecilnya.

== 5.7 Bivariat Kontinu
<bivariat-kontinu>
=== K --- Konteks
<k-konteks-35>
Banyak pasangan peubah acak lebih alami dimodelkan kontinu, misalnya: - tinggi dan berat badan, - suhu dan konsumsi listrik, - waktu proses tahap 1 dan tahap 2.

=== M --- Model
<m-model-35>
Joint density $f_(X \, Y) \( x \, y \)$ memberi kerapatan peluang pasangan $\( X \, Y \)$.

Peluang pada daerah $A$ adalah: $ P \( \( X \, Y \) in A \) = integral.double_A f_(X \, Y) \( x \, y \) thin d x thin d y $

=== Q --- Questions
<q-questions-35>
+ Bagaimana membayangkan distribusi bersama kontinu?
+ Bagaimana memperoleh marginal?
+ Bagaimana memvisualisasikannya?

=== A --- Apply
<a-apply-34>
Mari ambil contoh Normal bivariat.

#Skylighting(([#NormalTok("mean ");#OperatorTok("=");#NormalTok(" [");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok("]");],
[#NormalTok("cov ");#OperatorTok("=");#NormalTok(" [[");#DecValTok("1");#NormalTok(", ");#FloatTok("0.8");#NormalTok("],");],
[#NormalTok("       [");#FloatTok("0.8");#NormalTok(", ");#DecValTok("1");#NormalTok("]]");],
[],
[#NormalTok("data ");#OperatorTok("=");#NormalTok(" rng.multivariate_normal(mean, cov, size");#OperatorTok("=");#DecValTok("5000");#NormalTok(")");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" data[:,");#DecValTok("0");#NormalTok("]");],
[#NormalTok("Y ");#OperatorTok("=");#NormalTok(" data[:,");#DecValTok("1");#NormalTok("]");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(",");#DecValTok("5");#NormalTok("))");],
[#NormalTok("plt.scatter(X, Y, alpha");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", s");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"X\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Y\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Scatterplot Normal bivariat\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-13-output-1.svg"))

Marginalnya dapat dilihat dari histogram tiap komponen.

#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("3");#NormalTok("))");],
[],
[#NormalTok("plt.subplot(");#DecValTok("1");#NormalTok(",");#DecValTok("2");#NormalTok(",");#DecValTok("1");#NormalTok(")");],
[#NormalTok("plt.hist(X, bins");#OperatorTok("=");#DecValTok("40");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.7");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Marginal X\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[],
[#NormalTok("plt.subplot(");#DecValTok("1");#NormalTok(",");#DecValTok("2");#NormalTok(",");#DecValTok("2");#NormalTok(")");],
[#NormalTok("plt.hist(Y, bins");#OperatorTok("=");#DecValTok("40");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.7");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Marginal Y\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[],
[#NormalTok("plt.tight_layout()");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-14-output-1.svg"))

== 5.8 Kovariansi
<kovariansi>
=== K --- Konteks
<k-konteks-36>
Kita sering ingin tahu apakah dua peubah cenderung bergerak bersama. Misalnya: - semakin banyak pelanggan, semakin besar pendapatan, - semakin lama hujan, semakin kecil pengunjung, - semakin besar arus, semakin besar daya.

=== M --- Model
<m-model-36>
Kovariansi didefinisikan sebagai:

$ upright(C o v) \( X \, Y \) = E \[ \( X - E \[ X \] \) \( Y - E \[ Y \] \) \] $

Bentuk ekuivalennya: $ upright(C o v) \( X \, Y \) = E \[ X Y \] - E \[ X \] E \[ Y \] $

=== Q --- Questions
<q-questions-36>
+ Apa arti kovariansi positif, negatif, atau nol?
+ Mengapa satuan kovariansi sulit ditafsirkan langsung?
+ Bagaimana menghitungnya dari data?

=== A --- Apply
<a-apply-35>
#block[
#Skylighting(([#NormalTok("cov_xy ");#OperatorTok("=");#NormalTok(" np.cov(X, Y, ddof");#OperatorTok("=");#DecValTok("0");#NormalTok(")[");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("]");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Cov(X,Y) =\"");#NormalTok(", cov_xy)");],));
#block[
#Skylighting(([#NormalTok("Cov(X,Y) = 0.7693398942915717");],));
]
]
==== Interpretasi
<interpretasi-19>
- Kovariansi positif: saat $X$ di atas rata-rata, $Y$ cenderung juga di atas rata-rata.
- Kovariansi negatif: saat $X$ di atas rata-rata, $Y$ cenderung di bawah rata-rata.
- Kovariansi nol: tidak ada hubungan linear yang jelas, tetapi belum tentu independen.

== 5.9 Korelasi
<korelasi>
=== K --- Konteks
<k-konteks-37>
Kovariansi bagus, tetapi nilainya dipengaruhi satuan. Kita sering butuh ukuran yang lebih mudah dibandingkan antar-kasus.

=== M --- Model
<m-model-37>
Korelasi adalah versi ternormalisasi dari kovariansi:

$ rho_(X \, Y) = frac(upright(C o v) \( X \, Y \), sigma_X sigma_Y) $

Nilainya berada antara -1 dan 1.

=== Q --- Questions
<q-questions-37>
+ Apa arti korelasi mendekati 1, 0, atau -1?
+ Apa bedanya korelasi dan kovariansi?
+ Mengapa korelasi tidak otomatis berarti hubungan sebab-akibat?

=== A --- Apply
<a-apply-36>
#block[
#Skylighting(([#NormalTok("corr_xy ");#OperatorTok("=");#NormalTok(" np.corrcoef(X, Y)[");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("]");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Corr(X,Y) =\"");#NormalTok(", corr_xy)");],));
#block[
#Skylighting(([#NormalTok("Corr(X,Y) = 0.7855402048546878");],));
]
]
==== Interpretasi
<interpretasi-20>
- $rho approx 1$: hubungan linear positif kuat,
- $rho approx - 1$: hubungan linear negatif kuat,
- $rho approx 0$: hubungan linear lemah atau tidak ada.

=== Peringatan penting
<peringatan-penting>
Korelasi: - tidak berarti sebab-akibat, - tidak menangkap semua hubungan nonlinear, - bisa nol meskipun dua peubah sangat bergantung secara nonlinear.

== 5.10 Contoh: Korelasi Nol tetapi Tidak Independen
<contoh-korelasi-nol-tetapi-tidak-independen>
Ambil: - $X tilde.op upright(U n i f o r m) \( - 1 \, 1 \)$ - $Y = X^2$

Maka jelas $Y$ ditentukan sepenuhnya oleh $X$, jadi mereka #strong[tidak independen]. Namun korelasinya bisa nol.

#block[
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("123");#NormalTok(")");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" rng.uniform(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(", size");#OperatorTok("=");#DecValTok("100000");#NormalTok(")");],
[#NormalTok("Y ");#OperatorTok("=");#NormalTok(" X");#OperatorTok("**");#DecValTok("2");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Corr(X,Y) ~\"");#NormalTok(", np.corrcoef(X, Y)[");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("])");],));
#block[
#Skylighting(([#NormalTok("Corr(X,Y) ~ -0.0005791433843902291");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(",");#DecValTok("5");#NormalTok("))");],
[#NormalTok("plt.scatter(X, Y, alpha");#OperatorTok("=");#FloatTok("0.15");#NormalTok(", s");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"X\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Y = X^2\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Korelasi hampir nol, tetapi jelas tidak independen\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-18-output-1.svg"))

==== Pelajaran penting
<pelajaran-penting>
Korelasi nol #strong[bukan] bukti independensi.

== 5.11 Fungsi dari Random Variable
<fungsi-dari-random-variable>
=== K --- Konteks
<k-konteks-38>
Sering kali yang kita minati bukan random variable awal, tetapi #strong[fungsi] darinya.

Contoh: - jika arus $I$ acak, maka daya $P = I^2 R$, - jika harga $H$ dan jumlah terjual $Q$ acak, maka revenue $R = H Q$, - jika dua tahap layanan acak, total waktu $T = X_1 + X_2$.

=== M --- Model
<m-model-38>
Jika $X$ adalah random variable dan $Y = g \( X \)$, maka $Y$ juga random variable.

Untuk dua peubah, jika: $ Z = g \( X \, Y \) $ maka $Z$ juga random variable.

=== Q --- Questions
<q-questions-38>
+ Bagaimana distribusi berubah setelah transformasi?
+ Mengapa fungsi nonlinear bisa mengubah bentuk distribusi secara drastis?
+ Bagaimana Python membantu melihat perubahan ini?

=== A --- Apply
<a-apply-37>
Misalkan: $ I tilde.op cal(N) \( 10 \, 0.8^2 \) \, #h(2em) P = I^2 R \, quad R = 5 $

#block[
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("7");#NormalTok(")");],
[#NormalTok("I ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#DecValTok("10");#NormalTok(", scale");#OperatorTok("=");#FloatTok("0.8");#NormalTok(", size");#OperatorTok("=");#DecValTok("100000");#NormalTok(")");],
[#NormalTok("R ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[#NormalTok("P ");#OperatorTok("=");#NormalTok(" (I");#OperatorTok("**");#DecValTok("2");#NormalTok(") ");#OperatorTok("*");#NormalTok(" R");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean I =\"");#NormalTok(", I.mean(), ");#StringTok("\"Var I =\"");#NormalTok(", I.var())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean P =\"");#NormalTok(", P.mean(), ");#StringTok("\"Var P =\"");#NormalTok(", P.var())");],));
#block[
#Skylighting(([#NormalTok("Mean I = 9.998938944730092 Var I = 0.6378216295132455");],
[#NormalTok("Mean P = 503.0830082497668 Var P = 6392.509470652347");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(I, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", label");#OperatorTok("=");#StringTok("\"I\"");#NormalTok(")");],
[#NormalTok("plt.hist(P, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.6");#NormalTok(", label");#OperatorTok("=");#StringTok("\"P = I^2 R\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Nilai\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Fungsi nonlinear mengubah bentuk distribusi\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-20-output-1.svg"))

==== Interpretasi
<interpretasi-21>
Transformasi nonlinear dapat: - mengubah pusat, - mengubah varians, - mengubah skewness, - mengubah peluang melewati batas aman.

== 5.12 Fungsi dari Dua Random Variable
<fungsi-dari-dua-random-variable>
=== K --- Konteks
<k-konteks-39>
Banyak keputusan melibatkan gabungan dua random variable.

Contoh: - revenue $R = P times Q$, - total waktu $T = X + Y$, - keuntungan $G = upright("revenue") - upright("cost")$.

=== M --- Model
<m-model-39>
Jika $X$ dan $Y$ acak, maka: - $X + Y$, - $X Y$, - $a X + b Y$, - $max \( X \, Y \)$, - dan fungsi lain dari keduanya juga random variable.

=== Q --- Questions
<q-questions-39>
+ Bagaimana rata-rata jumlah dua random variable?
+ Bagaimana varians jumlah dua random variable?
+ Kapan covariance ikut berperan?

=== A --- Apply
<a-apply-38>
Untuk dua random variable: $ E \[ X + Y \] = E \[ X \] + E \[ Y \] $

dan: $ upright(V a r) \( X + Y \) = upright(V a r) \( X \) + upright(V a r) \( Y \) + 2 upright(C o v) \( X \, Y \) $

Mari verifikasi dengan simulasi.

#block[
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("11");#NormalTok(")");],
[#NormalTok("mean ");#OperatorTok("=");#NormalTok(" [");#DecValTok("10");#NormalTok(", ");#DecValTok("20");#NormalTok("]");],
[#NormalTok("cov ");#OperatorTok("=");#NormalTok(" [[");#DecValTok("4");#NormalTok(", ");#DecValTok("3");#NormalTok("],");],
[#NormalTok("       [");#DecValTok("3");#NormalTok(", ");#DecValTok("9");#NormalTok("]]");],
[],
[#NormalTok("data ");#OperatorTok("=");#NormalTok(" rng.multivariate_normal(mean, cov, size");#OperatorTok("=");#DecValTok("200000");#NormalTok(")");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" data[:,");#DecValTok("0");#NormalTok("]");],
[#NormalTok("Y ");#OperatorTok("=");#NormalTok(" data[:,");#DecValTok("1");#NormalTok("]");],
[#NormalTok("T ");#OperatorTok("=");#NormalTok(" X ");#OperatorTok("+");#NormalTok(" Y");],
[],
[#NormalTok("lhs_mean ");#OperatorTok("=");#NormalTok(" T.mean()");],
[#NormalTok("rhs_mean ");#OperatorTok("=");#NormalTok(" X.mean() ");#OperatorTok("+");#NormalTok(" Y.mean()");],
[],
[#NormalTok("lhs_var ");#OperatorTok("=");#NormalTok(" T.var()");],
[#NormalTok("rhs_var ");#OperatorTok("=");#NormalTok(" X.var() ");#OperatorTok("+");#NormalTok(" Y.var() ");#OperatorTok("+");#NormalTok(" ");#DecValTok("2");#OperatorTok("*");#NormalTok("np.cov(X, Y, ddof");#OperatorTok("=");#DecValTok("0");#NormalTok(")[");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("]");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean left  =\"");#NormalTok(", lhs_mean)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean right =\"");#NormalTok(", rhs_mean)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Var left   =\"");#NormalTok(", lhs_var)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Var right  =\"");#NormalTok(", rhs_var)");],));
#block[
#Skylighting(([#NormalTok("Mean left  = 29.99708921283331");],
[#NormalTok("Mean right = 29.99708921283331");],
[#NormalTok("Var left   = 18.908340698332005");],
[#NormalTok("Var right  = 18.908340698332005");],));
]
]
==== Interpretasi
<interpretasi-22>
Jika dua peubah berkorelasi positif, variance jumlahnya lebih besar daripada jika mereka independen. Ini sangat penting dalam: - risk aggregation, - portfolio, - total demand, - total delay.

== 5.13 KMQA Mini-Case 1 --- Tinggi dan Berat Badan
<kmqa-mini-case-1-tinggi-dan-berat-badan>
=== K --- Konteks
<k-konteks-40>
Kita ingin memahami hubungan tinggi badan dan berat badan.

=== M --- Model
<m-model-40>
$\( X \, Y \)$ = (tinggi, berat) dimodelkan sebagai random vector kontinu.

=== Q --- Questions
<q-questions-40>
+ Apakah keduanya berkorelasi?
+ Apakah korelasi tinggi berarti sebab-akibat?
+ Apa arti marginal masing-masing?

=== A --- Apply
<a-apply-39>
Gunakan scatterplot, covariance, dan correlation untuk melihat pola awal. Interpretasi harus hati-hati: hubungan statistik tidak otomatis berarti hubungan sebab-akibat.

== 5.14 KMQA Mini-Case 2 --- Jumlah Pelanggan dan Revenue
<kmqa-mini-case-2-jumlah-pelanggan-dan-revenue>
=== K --- Konteks
<k-konteks-41>
Sebuah toko ingin memodelkan: - $X$ = jumlah pelanggan, - $Y$ = revenue harian.

=== M --- Model
<m-model-41>
Secara sederhana, $Y$ sering meningkat saat $X$ meningkat. Bisa ada hubungan linear kasar atau model fungsi: $ Y = a X + epsilon.alt $

=== Q --- Questions
<q-questions-41>
+ Seberapa kuat hubungan keduanya?
+ Apakah variance revenue hanya ditentukan oleh variance pelanggan?
+ Apa implikasinya terhadap staffing dan stok?

=== A --- Apply
<a-apply-40>
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("2026");#NormalTok(")");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" rng.poisson(lam");#OperatorTok("=");#DecValTok("100");#NormalTok(", size");#OperatorTok("=");#DecValTok("5000");#NormalTok(")");],
[#NormalTok("eps ");#OperatorTok("=");#NormalTok(" rng.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("50");#NormalTok(", size");#OperatorTok("=");#DecValTok("5000");#NormalTok(")");],
[#NormalTok("Y ");#OperatorTok("=");#NormalTok(" ");#DecValTok("20");#OperatorTok("*");#NormalTok("X ");#OperatorTok("+");#NormalTok(" eps");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Cov(X,Y) =\"");#NormalTok(", np.cov(X,Y, ddof");#OperatorTok("=");#DecValTok("0");#NormalTok(")[");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("])");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Corr(X,Y) =\"");#NormalTok(", np.corrcoef(X,Y)[");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("])");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(",");#DecValTok("5");#NormalTok("))");],
[#NormalTok("plt.scatter(X, Y, alpha");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", s");#OperatorTok("=");#DecValTok("8");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Jumlah pelanggan\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Revenue\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Pelanggan dan revenue\"");#NormalTok(")");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#block[
#Skylighting(([#NormalTok("Cov(X,Y) = 1968.1527526251139");],
[#NormalTok("Corr(X,Y) = 0.9695696157524835");],));
]
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-22-output-2.svg"))

== 5.15 KMQA Mini-Case 3 --- Arus dan Daya
<kmqa-mini-case-3-arus-dan-daya>
=== K --- Konteks
<k-konteks-42>
Arus listrik $I$ acak, daya: $ P = I^2 R $

=== M --- Model
<m-model-42>
Daya adalah fungsi nonlinear dari arus.

=== Q --- Questions
<q-questions-42>
+ Mengapa variasi kecil di arus bisa diperbesar di daya?
+ Bagaimana distribusi daya dibanding distribusi arus?
+ Seberapa sering daya melewati batas aman?

=== A --- Apply
<a-apply-41>
#block[
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("77");#NormalTok(")");],
[#NormalTok("I ");#OperatorTok("=");#NormalTok(" rng.normal(");#DecValTok("10");#NormalTok(", ");#FloatTok("1.0");#NormalTok(", size");#OperatorTok("=");#DecValTok("100000");#NormalTok(")");],
[#NormalTok("R ");#OperatorTok("=");#NormalTok(" ");#DecValTok("4");],
[#NormalTok("P ");#OperatorTok("=");#NormalTok(" I");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" R");],
[],
[#NormalTok("threshold ");#OperatorTok("=");#NormalTok(" ");#DecValTok("500");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(P > 500) =\"");#NormalTok(", np.mean(P ");#OperatorTok(">");#NormalTok(" threshold))");],));
#block[
#Skylighting(([#NormalTok("P(P > 500) = 0.11884");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.hist(P, bins");#OperatorTok("=");#DecValTok("60");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.75");#NormalTok(")");],
[#NormalTok("plt.axvline(threshold, color");#OperatorTok("=");#StringTok("'red'");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("'--'");#NormalTok(", label");#OperatorTok("=");#StringTok("'Batas aman'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Daya\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Density\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Distribusi daya sebagai fungsi dari arus acak\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-24-output-1.svg"))

== 5.16 Python Toolbox untuk Bab Ini
<python-toolbox-untuk-bab-ini-1>
#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats");],));
]
=== Kovariansi dan korelasi
<kovariansi-dan-korelasi>
#Skylighting(([#NormalTok("X ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("1");#NormalTok(",");#DecValTok("2");#NormalTok(",");#DecValTok("3");#NormalTok(",");#DecValTok("4");#NormalTok("])");],
[#NormalTok("Y ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("2");#NormalTok(",");#DecValTok("3");#NormalTok(",");#DecValTok("5");#NormalTok(",");#DecValTok("7");#NormalTok("])");],
[],
[#NormalTok("np.cov(X, Y, ddof");#OperatorTok("=");#DecValTok("0");#NormalTok("), np.corrcoef(X, Y)");],));
#Skylighting(([#NormalTok("(array([[1.25  , 2.125 ],");],
[#NormalTok("        [2.125 , 3.6875]]),");],
[#NormalTok(" array([[1.        , 0.98977827],");],
[#NormalTok("        [0.98977827, 1.        ]]))");],));
=== Simulasi multivariate normal
<simulasi-multivariate-normal>
#Skylighting(([#NormalTok("mean ");#OperatorTok("=");#NormalTok(" [");#DecValTok("0");#NormalTok(",");#DecValTok("0");#NormalTok("]");],
[#NormalTok("cov ");#OperatorTok("=");#NormalTok(" [[");#DecValTok("1");#NormalTok(",");#FloatTok("0.6");#NormalTok("],[");#FloatTok("0.6");#NormalTok(",");#DecValTok("1");#NormalTok("]]");],
[#NormalTok("sample ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("0");#NormalTok(").multivariate_normal(mean, cov, size");#OperatorTok("=");#DecValTok("5");#NormalTok(")");],
[#NormalTok("sample");],));
#Skylighting(([#NormalTok("array([[-0.05337744, -0.17153562],");],
[#NormalTok("       [-0.61972419, -0.52589867],");],
[#NormalTok("       [ 0.31740703,  0.64082748],");],
[#NormalTok("       [-1.58988058, -0.74278561],");],
[#NormalTok("       [ 1.19535362,  0.06352624]])");],));
=== Heatmap joint distribution diskrit
<heatmap-joint-distribution-diskrit>
#Skylighting(([#NormalTok("joint ");#OperatorTok("=");#NormalTok(" np.array([[");#FloatTok("0.1");#NormalTok(", ");#FloatTok("0.2");#NormalTok("],[");#FloatTok("0.3");#NormalTok(", ");#FloatTok("0.4");#NormalTok("]])");],
[#NormalTok("plt.imshow(joint, cmap");#OperatorTok("=");#StringTok("'Blues'");#NormalTok(", origin");#OperatorTok("=");#StringTok("'lower'");#NormalTok(")");],
[#NormalTok("plt.colorbar()");],
[#NormalTok("plt.show()");],));
#box(image("05-random-variable-multivariat-dan-fungsi_files/figure-typst/cell-28-output-1.svg"))

== 5.17 Kesalahan Umum yang Harus Dihindari
<kesalahan-umum-yang-harus-dihindari-2>
+ #strong[Menganggap joint distribution hanya dua histogram ditempel bersama] \
  Tidak. Joint distribution memuat struktur hubungan keduanya.

+ #strong[Menganggap marginal sudah cukup untuk semua keputusan] \
  Tidak. Kadang hubungan antar peubah justru inti persoalannya.

+ #strong[Menganggap korelasi berarti sebab-akibat] \
  Tidak. Korelasi hanya ukuran asosiasi linear.

+ #strong[Menganggap korelasi nol berarti independen] \
  Tidak selalu.

+ #strong[Mengabaikan covariance saat menghitung variance jumlah] \
  Ini kesalahan penting dalam banyak aplikasi risiko.

+ #strong[Lupa bahwa fungsi dari random variable juga random variable] \
  Dalam banyak desain sistem, justru peubah turunan itulah yang paling penting.

== 5.18 Menyimpulkan Bab Ini
<menyimpulkan-bab-ini-4>
Bab ini memperluas perspektif kita dari satu random variable menjadi dunia yang lebih realistis: dunia dengan beberapa peubah acak yang bisa saling terkait.

Kita telah melihat: - joint distribution, - marginal distribution, - conditional distribution, - independensi, - kovariansi, - korelasi, - fungsi dari satu random variable, - dan fungsi dari beberapa random variable.

Ini adalah langkah penting menuju cara berpikir yang lebih matang. Dunia nyata jarang sesederhana satu peubah acak. Justru keputusan yang baik sering muncul ketika kita mampu melihat hubungan antarpeubah dan memahami bagaimana ketidakpastian merambat dari input ke output.

== 5.19 Ringkasan Poin Inti
<ringkasan-poin-inti-4>
+ Banyak masalah nyata melibatkan #strong[lebih dari satu random variable].
+ #strong[Joint distribution] menggambarkan perilaku pasangan peubah secara simultan.
+ #strong[Marginal distribution] diperoleh dengan “menjumlahkan” atau “mengintegralkan keluar” peubah lain.
+ #strong[Conditional distribution] adalah distribusi yang relevan ketika informasi tambahan tersedia.
+ #strong[Independensi] adalah syarat kuat: joint = hasil kali marginals.
+ #strong[Covariance] mengukur kecenderungan bergerak bersama.
+ #strong[Correlation] menormalkan covariance agar lebih mudah ditafsirkan.
+ Korelasi nol #strong[tidak selalu] berarti independen.
+ Fungsi dari random variable juga merupakan random variable.
+ Dalam banyak keputusan nyata, justru random variable turunan seperti revenue, total delay, daya, dan profit yang paling penting.

== 5.20 Latihan Bab 5
<latihan-bab-5>
=== A. Konseptual
<a.-konseptual-4>
+ Jelaskan perbedaan joint, marginal, dan conditional distribution.
+ Apa arti dua random variable independen?
+ Apa bedanya covariance dan correlation?
+ Mengapa korelasi nol tidak menjamin independensi?

=== B. Hitungan
<b.-hitungan-3>
+ Diberi joint PMF tabel kecil, hitung marginal $p_X$ dan $p_Y$.
+ Hitung conditional distribution $P \( X = x divides Y = y \)$.
+ Jika diketahui $E \[ X \] \, E \[ Y \] \, upright(V a r) \( X \) \, upright(V a r) \( Y \) \, upright(C o v) \( X \, Y \)$, hitung $E \[ X + Y \]$ dan $upright(V a r) \( X + Y \)$.

=== C. Python
<c.-python-3>
+ Simulasikan dua peubah acak yang berkorelasi positif lalu hitung covariance dan correlation.
+ Simulasikan contoh $Y = X^2$ untuk menunjukkan korelasi nol tetapi tidak independen.
+ Simulasikan model revenue sebagai fungsi dari jumlah pelanggan.

=== D. Aplikatif
<d.-aplikatif-3>
+ Dalam konteks klinik, peubah apa saja yang masuk akal dimodelkan bersama?
+ Dalam konteks manufaktur, mengapa jumlah cacat dan biaya garansi sebaiknya dipikirkan bersama?
+ Dalam konteks listrik, mengapa distribusi daya lebih penting daripada sekadar distribusi arus?

== 5.21 Penutup Kecil
<penutup-kecil-4>
Dengan bab ini, Anda sudah punya salah satu kemampuan yang sangat penting dalam probabilitas: melihat bahwa ketidakpastian jarang berdiri sendiri. Ia biasanya datang berpasangan, berkelompok, saling terkait, dan sering kali menghasilkan peubah baru yang lebih relevan bagi keputusan.

Di bab terakhir, kita akan menutup perjalanan ini dengan merangkum prinsip-prinsip utamanya: bagaimana random variable, distribusi, Python, dan pengambilan keputusan menyatu menjadi satu cara berpikir yang kuat.

= Bab 6. Penutup
<bab-6.-penutup>
== Tujuan Bab
<tujuan-bab-5>
Bab ini bertujuan untuk:

+ merangkum gagasan utama yang telah dipelajari sepanjang buku,
+ menegaskan kembali hubungan antara #strong[random variable], #strong[probabilitas], #strong[Python], dan #strong[pengambilan keputusan],
+ membantu mahasiswa melihat struktur besar dari seluruh materi,
+ menutup perjalanan belajar ini dengan nada yang menguatkan, realistis, dan inspiratif.

== Pembuka
<pembuka-5>
Kalau Anda sudah sampai pada bab ini, berarti Anda telah menempuh sebuah perjalanan intelektual yang cukup penting.

Di awal, mungkin probabilitas dan statistika tampak seperti kumpulan rumus yang asing. Ada simbol, distribusi, integral, penjumlahan, dan notasi yang mudah terasa jauh dari kehidupan nyata. Tetapi sepanjang buku ini, kita berusaha menempuh jalan yang berbeda. Kita tidak memulai dari rumus demi rumus. Kita memulai dari #strong[pertanyaan nyata]:

- bagaimana memilih keputusan ketika masa depan belum pasti?
- bagaimana membandingkan pilihan yang sama-sama mungkin untung?
- bagaimana menilai risiko?
- bagaimana memodelkan jumlah, waktu, umur hidup, profit, dan kegagalan?
- bagaimana menggunakan Python untuk melihat, mencoba, dan memahami?

Bab ini adalah tempat kita berhenti sejenak, melihat ke belakang, lalu menyadari apa yang sebenarnya sudah kita pelajari.

== 6.1 Ide Besar Buku Ini
<ide-besar-buku-ini>
Ada satu ide besar yang mengikat seluruh buku ini:

#quote(block: true)[
#strong[Probabilitas dan statistika adalah alat berpikir untuk membuat keputusan di bawah ketidakpastian.]
]

Di balik semua contoh, distribusi, simulasi, dan rumus, ada satu kebutuhan yang sama: kita ingin bertindak dengan lebih bijaksana meskipun kita tidak tahu masa depan secara pasti.

Kita belajar bahwa: - masa depan sering kali tidak pasti, - tetapi ketidakpastian itu bukan alasan untuk menyerah, - justru dengan model yang tepat, kita bisa berpikir lebih jernih.

Dan salah satu model terpenting yang kita pelajari adalah #strong[random variable].

== 6.2 Apa yang Sebenarnya Sudah Kita Kuasai?
<apa-yang-sebenarnya-sudah-kita-kuasai>
Mari kita lihat ulang perjalanan kita.

=== Dari ketidakpastian ke angka
<dari-ketidakpastian-ke-angka>
Kita belajar bahwa random variable adalah cara memetakan dunia acak ke bilangan. Ini adalah langkah yang sangat besar. Begitu hasil acak dipetakan menjadi angka, kita bisa: - menghitung peluang, - mencari rata-rata, - mengukur variasi, - membandingkan pilihan, - membangun simulasi, - dan merancang keputusan.

=== Dari angka ke distribusi
<dari-angka-ke-distribusi>
Kita belajar bahwa satu angka tidak cukup. Yang lebih penting adalah #strong[bagaimana peluang tersebar] pada nilai-nilai yang mungkin. Itulah distribusi.

Distribusi membuat kita bertanya: - apa nilai yang mungkin? - seberapa mungkin? - seberapa besar peluang berada di bawah batas tertentu? - seberapa liar penyimpangannya?

=== Dari mean ke risk
<dari-mean-ke-risk>
Kita belajar bahwa mean atau ekspektasi sangat penting, tetapi tidak cukup. Dua pilihan dengan rata-rata sama belum tentu sama baik. Variance, simpangan baku, dan bentuk distribusi ikut menentukan kualitas keputusan.

=== Dari satu peubah ke beberapa peubah
<dari-satu-peubah-ke-beberapa-peubah>
Kita belajar bahwa dunia nyata jarang hanya punya satu peubah acak. Sering kali kita perlu memikirkan pasangan atau kelompok peubah acak: - pelanggan dan revenue, - tinggi dan berat, - arus dan daya, - jumlah cacat dan biaya garansi.

Dari situ kita belajar joint distribution, marginal, conditional, covariance, correlation, dan transformasi fungsi.

=== Dari teori ke eksperimen
<dari-teori-ke-eksperimen>
Kita juga belajar bahwa Python bukan sekadar kalkulator. Python adalah laboratorium kecil yang memungkinkan kita: - mencoba ide, - melihat pola, - menjalankan simulasi Monte Carlo, - memverifikasi rumus, - dan membangun intuisi.

== 6.3 Ringkasan Per Bab
<ringkasan-per-bab>
=== Bab 1 --- Pendahuluan: Pengambilan Keputusan
<bab-1-pendahuluan-pengambilan-keputusan>
Bab pertama menanamkan pesan utama buku ini: probabilitas bukan sekadar kumpulan rumus, tetapi cara berpikir saat masa depan belum pasti. Melalui contoh investasi, produk cacat, garansi, fungsi random variable, risiko bangkrut, dan klinik gigi, kita melihat bahwa probabilitas hidup dalam keputusan nyata.

=== Bab 2 --- Random Variable Umum
<bab-2-random-variable-umum>
Bab kedua memberi fondasi formal: - random variable sebagai fungsi, - range, - diskrit dan kontinu, - PMF, CDF, PDF, - ekspektasi, - varians, - simpangan baku.

Inilah kerangka dasar yang menopang semua bab sesudahnya.

=== Bab 3 --- Distribusi Diskrit
<bab-3-distribusi-diskrit>
Bab ketiga mengenalkan keluarga distribusi diskrit: - uniform diskrit, - Bernoulli, - Binomial, - Geometric, - Poisson, - serta distribusi kustom dari histogram.

Di sini kita belajar memilih model untuk hitungan kejadian.

=== Bab 4 --- Distribusi Kontinu
<bab-4-distribusi-kontinu>
Bab keempat membawa kita ke dunia waktu, umur hidup, dan pengukuran: - uniform kontinu, - normal, - gamma, - exponential, - erlang, - weibull, - pareto, - chi-square, - serta hubungan antardistribusi.

Di sini kita melihat bahwa banyak fenomena dunia nyata lebih nyaman dipandang kontinu.

=== Bab 5 --- Multivariat dan Fungsi Random Variable
<bab-5-multivariat-dan-fungsi-random-variable>
Bab kelima memperluas perspektif: - joint distribution, - marginal, - conditional, - independensi, - covariance, - correlation, - fungsi random variable.

Di sini kita melihat bahwa ketidakpastian sering datang bersama-sama dan sering menghasilkan peubah turunan yang justru paling penting bagi keputusan.

== 6.4 Prinsip-Prinsip Inti yang Perlu Diingat
<prinsip-prinsip-inti-yang-perlu-diingat>
Berikut adalah beberapa prinsip inti yang layak dibawa terus, bahkan setelah buku ini selesai dibaca.

=== 1. Mulai dari konteks, bukan dari rumus
<mulai-dari-konteks-bukan-dari-rumus>
Ketika menghadapi masalah baru, jangan buru-buru bertanya “rumus apa yang dipakai?” \
Mulailah dari: - apa keputusannya, - apa yang tidak pasti, - apa random variable-nya, - apa ukuran yang perlu dihitung.

=== 2. Model yang baik lebih penting daripada rumus yang banyak
<model-yang-baik-lebih-penting-daripada-rumus-yang-banyak>
Banyak kesalahan datang bukan karena salah menghitung, tetapi karena salah memodelkan. Distribusi yang salah akan menghasilkan keputusan yang salah.

=== 3. Ekspektasi penting, tetapi variance juga penting
<ekspektasi-penting-tetapi-variance-juga-penting>
Mean memberi arah, variance memberi ukuran ombaknya. Dalam banyak masalah nyata, survival, safety, dan reliability sangat dipengaruhi variance.

=== 4. PDF bukan peluang
<pdf-bukan-peluang>
Untuk random variable kontinu, peluang datang dari area, bukan dari tinggi kurva.

=== 5. Korelasi bukan sebab-akibat
<korelasi-bukan-sebab-akibat>
Dua peubah bisa berkorelasi tanpa salah satunya menyebabkan yang lain. Statistik membantu melihat pola, tetapi interpretasi tetap membutuhkan akal sehat dan konteks.

=== 6. Python membantu belajar, bukan menggantikan berpikir
<python-membantu-belajar-bukan-menggantikan-berpikir>
Kode yang baik bukan jalan pintas untuk menghindari pemahaman. Sebaliknya, Python memberi kita kesempatan untuk menguji pemahaman secara aktif.

=== 7. Ketidakpastian bisa dimodelkan, meskipun tidak bisa dihilangkan
<ketidakpastian-bisa-dimodelkan-meskipun-tidak-bisa-dihilangkan>
Kita tidak akan pernah menghapus ketidakpastian dari hidup dan sistem nyata. Tetapi kita bisa menghadapinya dengan lebih terstruktur.

== 6.5 Checklist Kompetensi
<checklist-kompetensi>
Berikut checklist sederhana. Jika Anda sudah mampu melakukan sebagian besar hal di bawah ini, berarti Anda sudah menempuh langkah yang sangat baik.

=== Konseptual
<konseptual>
- ☐ Saya bisa menjelaskan apa itu random variable.
- ☐ Saya bisa membedakan random variable diskrit dan kontinu.
- ☐ Saya tahu perbedaan PMF, PDF, dan CDF.
- ☐ Saya bisa menjelaskan ekspektasi dan variance dengan kata-kata sendiri.
- ☐ Saya tahu arti joint, marginal, conditional, covariance, dan correlation.

=== Pemodelan
<pemodelan>
- ☐ Saya bisa memilih distribusi diskrit yang tepat untuk konteks count data.
- ☐ Saya bisa memilih distribusi kontinu yang masuk akal untuk waktu tunggu atau lifetime.
- ☐ Saya bisa menjelaskan arti parameter suatu distribusi.
- ☐ Saya bisa memodelkan output sebagai fungsi dari input acak.

=== Komputasional
<komputasional>
- ☐ Saya bisa mensimulasikan random variable dengan Python.
- ☐ Saya bisa menggambar histogram, PMF, PDF, atau CDF.
- ☐ Saya bisa memakai #NormalTok("numpy");, #NormalTok("scipy.stats");, dan #NormalTok("matplotlib");.
- ☐ Saya bisa membandingkan hasil simulasi dengan model teoritis.

=== Keputusan
<keputusan>
- ☐ Saya bisa menggunakan peluang untuk menilai risiko.
- ☐ Saya bisa menggunakan ekspektasi dan variance untuk membandingkan pilihan.
- ☐ Saya bisa menjelaskan implikasi keputusan berdasarkan model probabilistik.

== 6.6 Python sebagai Partner Belajar
<python-sebagai-partner-belajar>
Sepanjang buku ini, Python hadir bukan sekadar sebagai aksesoris. Python dipakai karena ia memberi beberapa keuntungan penting.

=== 1. Python memberi quick wins
<python-memberi-quick-wins>
Mahasiswa tidak perlu menunggu lama untuk merasakan bahwa konsep probabilitas benar-benar bekerja. Dengan beberapa baris kode, kita bisa: - mensimulasikan eksperimen, - membuat histogram, - menghitung mean dan variance, - membandingkan Monte Carlo dan teori.

=== 2. Python membantu membangun intuisi
<python-membantu-membangun-intuisi>
Sebelum semua definisi terasa nyaman, visualisasi dan simulasi sudah lebih dulu memberi “rasa” terhadap konsep.

=== 3. Python membantu mengecek asumsi
<python-membantu-mengecek-asumsi>
Dalam praktik nyata, kita jarang tahu jawaban dengan pasti. Simulasi membantu memeriksa apakah intuisi kita masuk akal.

=== 4. Python membuat belajar lebih aktif
<python-membuat-belajar-lebih-aktif>
Daripada hanya membaca rumus, mahasiswa bisa mengubah parameter, menjalankan ulang simulasi, dan melihat apa yang berubah. Ini membuat belajar menjadi proses eksplorasi, bukan hanya konsumsi.

== 6.7 Dari Probabilitas ke Cara Berpikir Engineer
<dari-probabilitas-ke-cara-berpikir-engineer>
Buku ini tidak hanya ingin mengajarkan isi mata kuliah. Buku ini juga ingin menanamkan kebiasaan berpikir yang lebih matang. Seorang engineer atau data scientist yang baik biasanya berpikir seperti ini:

+ #strong[Pahami konteksnya]
+ #strong[Tentukan apa yang acak]
+ #strong[Bangun random variable yang relevan]
+ #strong[Pilih model distribusi yang masuk akal]
+ #strong[Hitung ukuran yang penting]
+ #strong[Gunakan simulasi bila perlu]
+ #strong[Ambil keputusan dengan sadar akan asumsi dan risiko]

Ini adalah pola berpikir yang jauh melampaui mata kuliah ini. Pola ini akan sangat berguna dalam: - machine learning, - analitik data, - reliability engineering, - keuangan, - quality control, - sistem antrian, - dan banyak bidang lain.

== 6.8 Sebuah Catatan Tentang Ketidakpastian
<sebuah-catatan-tentang-ketidakpastian>
Ada satu pelajaran yang lebih filosofis di balik seluruh probabilitas.

Kita hidup di dunia yang tidak sepenuhnya pasti. Kita sering harus bertindak tanpa mengetahui semua hal. Kadang hasilnya baik, kadang tidak. Probabilitas tidak memberi kita kuasa untuk mengendalikan masa depan sepenuhnya. Tetapi probabilitas memberi kita sesuatu yang sangat penting: #strong[kerendahan hati dan keberanian].

- Rendah hati, karena kita tahu bahwa model kita tetap model, bukan kenyataan itu sendiri.
- Berani, karena walaupun tidak tahu segalanya, kita tetap bisa membuat keputusan yang lebih baik daripada sekadar menebak.

Dalam arti itu, probabilitas adalah latihan intelektual sekaligus latihan karakter.

== 6.9 Arah Belajar Lanjut
<arah-belajar-lanjut>
Setelah random variable, ada banyak topik lanjutan yang menunggu. Misalnya:

=== 1. Sampling distribution
<sampling-distribution>
Bagaimana statistik dari sampel juga menjadi random variable.

=== 2. Estimasi
<estimasi>
Bagaimana menebak parameter populasi dari data.

=== 3. Uji hipotesis
<uji-hipotesis>
Bagaimana membuat keputusan formal dari data.

=== 4. Inferensi Bayesian
<inferensi-bayesian>
Bagaimana memperbarui keyakinan saat data baru datang.

=== 5. Proses stokastik
<proses-stokastik>
Bagaimana memodelkan ketidakpastian yang berkembang terhadap waktu.

=== 6. Machine learning probabilistik
<machine-learning-probabilistik>
Bagaimana ide probabilitas dipakai dalam klasifikasi, prediksi, dan generative modeling.

Dengan kata lain, random variable bukanlah akhir. Ia adalah pintu masuk ke wilayah yang jauh lebih luas.

== 6.10 Sebuah Simulasi Penutup Kecil
<sebuah-simulasi-penutup-kecil>
Untuk menutup, mari kembali ke ide paling dasar: jika dunia acak, kita tidak harus menyerah. Kita bisa mensimulasikan, melihat pola, lalu memahami.

Misalkan kita bandingkan rata-rata dari sampel acak Normal saat ukuran sampel membesar.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("2026");#NormalTok(")");],
[],
[#NormalTok("true_mu ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("true_sigma ");#OperatorTok("=");#NormalTok(" ");#DecValTok("15");],
[],
[#NormalTok("sample_sizes ");#OperatorTok("=");#NormalTok(" [");#DecValTok("5");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("30");#NormalTok(", ");#DecValTok("100");#NormalTok(", ");#DecValTok("500");#NormalTok("]");],
[#NormalTok("means ");#OperatorTok("=");#NormalTok(" []");],
[],
[#ControlFlowTok("for");#NormalTok(" n ");#KeywordTok("in");#NormalTok(" sample_sizes:");],
[#NormalTok("    sample ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#NormalTok("true_mu, scale");#OperatorTok("=");#NormalTok("true_sigma, size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("    means.append(sample.mean())");],
[],
[#BuiltInTok("print");#NormalTok("(");#BuiltInTok("list");#NormalTok("(");#BuiltInTok("zip");#NormalTok("(sample_sizes, means)))");],));
#block[
#Skylighting(([#NormalTok("[(5, np.float64(98.75556672945466)), (10, np.float64(100.67853136094531)), (30, np.float64(101.5093331179185)), (100, np.float64(100.4519454787968)), (500, np.float64(100.66502613594935))]");],));
]
]
#Skylighting(([#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(",");#DecValTok("4");#NormalTok("))");],
[#NormalTok("plt.plot(sample_sizes, means, marker");#OperatorTok("=");#StringTok("'o'");#NormalTok(", label");#OperatorTok("=");#StringTok("'Sample mean'");#NormalTok(")");],
[#NormalTok("plt.axhline(true_mu, color");#OperatorTok("=");#StringTok("'red'");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("'--'");#NormalTok(", label");#OperatorTok("=");#StringTok("'True mean'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Ukuran sampel\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Rata-rata sampel\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Semakin banyak data, estimasi rata-rata cenderung stabil\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("06-penutup_files/figure-typst/cell-3-output-1.svg"))

Simulasi kecil ini mengingatkan kita pada sesuatu yang sederhana tetapi penting: - ketidakpastian tidak hilang, - tetapi dengan model, data, dan perhitungan, kita bisa bergerak menuju pemahaman yang lebih stabil.

== 6.11 Ringkasan Besar Buku
<ringkasan-besar-buku>
Kalau seluruh buku ini harus diringkas dalam beberapa kalimat, mungkin bunyinya seperti ini:

+ Dunia nyata penuh ketidakpastian.
+ Random variable adalah cara memetakan ketidakpastian itu ke bilangan.
+ Distribusi menjelaskan bagaimana peluang tersebar.
+ Ekspektasi, variance, dan ukuran lain membantu kita menilai pilihan.
+ Banyak keputusan nyata memerlukan lebih dari satu peubah acak.
+ Python membuat konsep-konsep ini bisa dilihat, dicoba, dan diuji.
+ Tujuan akhir probabilitas bukan sekadar menjawab soal, tetapi membantu kita #strong[berpikir lebih jernih saat harus memilih].

== 6.12 Pesan untuk Mahasiswa
<pesan-untuk-mahasiswa>
Kalau Anda pernah merasa probabilitas itu sulit, itu wajar. Banyak orang merasakannya. Tetapi sulit bukan berarti mustahil. Sering kali yang dibutuhkan bukan hanya lebih banyak rumus, melainkan cara masuk yang tepat: konteks yang hidup, contoh yang relevan, visualisasi yang jelas, dan keberanian untuk mencoba.

Semoga buku ini sudah memberi jalan masuk itu.

Yang lebih penting lagi: semoga setelah mempelajari buku ini, Anda tidak hanya menjadi mahasiswa yang bisa menghitung peluang, tetapi juga seseorang yang lebih cermat dalam berpikir, lebih jujur terhadap asumsi, dan lebih bertanggung jawab saat mengambil keputusan.

== 6.13 Ringkasan Poin Inti
<ringkasan-poin-inti-5>
+ Probabilitas adalah alat berpikir di bawah ketidakpastian.
+ Random variable adalah fondasi utama untuk memodelkan dunia acak.
+ Distribusi, mean, variance, dan CDF membantu kita membuat keputusan yang lebih baik.
+ Banyak persoalan nyata melibatkan joint behavior beberapa peubah acak.
+ Fungsi dari peubah acak sering kali justru menjadi besaran yang paling relevan.
+ Python membantu mengubah konsep menjadi pengalaman belajar yang konkret.
+ Tujuan akhir belajar probabilitas bukan sekadar lulus ujian, tetapi bertumbuh dalam cara berpikir.

== 6.14 Latihan Penutup
<latihan-penutup>
=== Reflektif
<reflektif>
+ Konsep apa yang paling mengubah cara Anda melihat probabilitas?
+ Kasus mana dalam buku ini yang paling terasa relevan bagi Anda?
+ Apa hubungan antara probabilitas dan tanggung jawab dalam mengambil keputusan?

=== Konseptual
<konseptual-1>
+ Mengapa random variable menjadi jembatan antara dunia acak dan matematika?
+ Mengapa mean saja sering tidak cukup?
+ Apa perbedaan penting antara korelasi dan independensi?

=== Komputasional
<komputasional-1>
+ Pilih satu distribusi diskrit dan satu distribusi kontinu dari buku ini, lalu buat simulasi dan visualisasi ulang dengan parameter pilihan Anda sendiri.
+ Buat satu mini-case baru dan modelkan dengan random variable yang sesuai.

== 6.15 Penutup Akhir
<penutup-akhir>
Buku ini sendiri lahir dari sebuah keputusan: keputusan untuk mengajarkan probabilitas dan statistika bukan sebagai tumpukan simbol yang dingin, tetapi sebagai ilmu yang dekat dengan pilihan nyata, logika yang hidup, dan eksplorasi yang menyenangkan.

Kalau setelah perjalanan ini Anda mulai melihat dunia dengan pertanyaan seperti: - “apa random variable-nya?” - “apa distribusinya?” - “berapa mean dan variance-nya?” - “apa risiko dari keputusan ini?” - “bisakah saya simulasikan dulu di Python?”

maka buku ini sudah mencapai tujuannya.

Selamat melanjutkan perjalanan belajar. Ketidakpastian tidak akan pernah hilang dari dunia nyata. Tetapi sekarang Anda sudah memiliki bahasa, alat, dan cara berpikir yang lebih kuat untuk menghadapinya.
