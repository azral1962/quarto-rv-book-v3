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
  title: [Problem Set 5: Probabilitas dan Statistik],
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
Probabilitas fungsi distribusi waktu untuk mengalami kegagalan pada sebuah komponen elektronik pada sebuah mesin foto kopi (dalam satuan waktu jam) adalah $f \( x \) = e^(- x \/ 1000) / 1000$ untuk setiap nilai $x > 0$. Hitung probabilitas dari: a. Komponen bertahan lebih dari 3000 jam sebelum akhirnya mengalami kegagalan. b. Komponen gagal dalam rentang 1000 hingga 2000 jam. c.~Komponen gagal sebelum 1000 jam. d.~Hitung jumlah jam saat 10% dari seluruh komponen yang ada mengalami kegagalan.

#strong[Jawaban:] Fungsi distribusi kumulatif (CDF): $ F \( x \) = integral_(- oo)^x e^(- t \/ 1000) / 1000 d t = 1 - e^(- x \/ 1000) $ a. Probabilitas komponen bertahan lebih dari 3000 jam: $ P \( X > 3000 \) = 1 - P \( X lt.eq 3000 \) = 1 - \( 1 - e^(- 3000 \/ 1000) \) = 0 \, 049787 $ b. Probabilitas komponen gagal dalam rentang 1000 hingga 2000 jam: $ P \( 1000 < X < 2000 \) = F \( 2000 \) - F \( 1000 \) = \( 1 - e^(- 2000 \/ 1000) \) - \( 1 - e^(- 1000 \/ 1000) \) = 0 \, 232544 $ c.~Probabilitas komponen gagal sebelum 1000 jam: $ P \( X < 1000 \) = 1 - e^(- 1000 \/ 1000) = 0 \, 63212 $ d.~Jumlah jam saat 10% komponen gagal: $ P \( X < x \) = 0 \, 1 $ $ 0 \, 1 = 1 - e^(- x \/ 1000) arrow.r.double.long e^(- x \/ 1000) = 0 \, 9 arrow.r.double.long - x / 1000 = ln \( 0 \, 9 \) arrow.r.double.long x = 105 \, 3605 upright(" jam") $

#emph[\(Bersumber dari penyelesaian distribusi komponen elektronik)].

#horizontalrule

== #strong[Soal 2]
<soal-2>
Lebar gap merupakan properti yang penting pada suatu kepala rekaman magnetik. Dalam satuan #emph[coded], jika lebar yang dimaksud merupakan sebuah variabel yang #emph[random] secara kontinu pada rentang nilai $0 < x < 2$, dengan $f \( x \) = 0 \, 5 x$. Tentukan fungsi distribusi kumulatif dari variabel lebar gap.

#strong[Jawaban:] $ F \( x \) = integral_(- oo)^x f \( t \) d t $ $ F \( x \) = cases(delim: "{", 0 \, & upright("untuk ") x lt.eq 0, 0 \, 25 x^2 \, & upright("untuk ") 0 < x < 2, 1 \, & upright("untuk ") x gt.eq 2) $

#emph[\(Bersumber dari penyelesaian variabel kontinu lebar gap)].

#horizontalrule

== #strong[Soal 3]
<soal-3>
Ketebalan sebuah #emph[conductive coating] dalam satuan mikrometer memiliki fungsi kepadatan $f \( x \) = 600 x^(- 2)$ untuk setiap nilai $100 < x < 120$ mikrometer, dan 0 di lainnya. a. Tentukan nilai rata-rata dan variansi dari ketebalan #emph[conductive coating] tersebut. b. Jika proses #emph[coating] membutuhkan biaya \$0,50 per mikrometer ketebalan pada setiap bagian, berapa biaya rata-rata yang diperlukan untuk melakukan proses #emph[coating] per bagiannya?

#strong[Jawaban:] a. Nilai Rata-rata ($E \( X \)$): $ E \( X \) = integral_(- oo)^oo x f \( x \) d x = integral_100^120 x \( 600 x^(- 2) \) d x = integral_100^120 600 / x d x = 109 \, 39 $ Nilai Variansi ($sigma^2$): $ sigma^2 = integral_100^120 \( x - 109 \, 39 \)^2 \( 600 x^(- 2) \) d x = 33 \, 186 $ b. Biaya rata-rata (\$0,50/mikrometer): $ E \( 0 \, 5 X \) = 0 \, 5 E \( X \) = 0 \, 5 times 109 \, 39 = \$ 54 \, 69 $

#emph[\(Bersumber dari perhitungan mean, variansi, dan nilai harapan biaya pelapisan)].

#horizontalrule

== #strong[Soal 4]
<soal-4>
Asumsikan ukuran sebuah partikel kontaminasi (dalam satuan mikrometer) dapat dimodelkan seperti berikut, $f \( x \) = 2 x^(- 3)$ untuk setiap nilai $1 < x$. Tentukan nilai rata-rata dari $X$.

#strong[Jawaban:] $ mu = E \( X \) = integral_(- oo)^oo x f \( x \) d x = integral_1^oo x \( 2 x^(- 3) \) d x = integral_1^oo 2 x^(- 2) d x = 2 $

#emph[\(Bersumber dari perhitungan mean partikel kontaminasi dengan integral batas tak hingga)].

#horizontalrule

== #strong[Soal 5]
<soal-5>
Berat bersih (dalam pound) pada sebuah paket senyawa kimia herbisida seragam pada interval $49 \, 75 < x < 50 \, 25$ pounds. a. Tentukan nilai rata-rata dan variansi dari berat paket tersebut. b. Tentukan fungsi distribusi kumulatif dari berat paket tersebut. c.~Tentukan $P \( X < 50 \, 1 \)$. d.~Tentukan $P \( 49 \, 9 < X < 50 \)$.

#strong[Jawaban:] a. Nilai Rata-rata ($E \( X \)$): $ E \( X \) = integral_(49 \, 75)^(50 \, 25) x \( 2 \) d x = 50 $ #emph[\(Catatan: Variansi untuk distribusi seragam dapat dihitung dengan rumus $\( b - a \)^2 \/ 12 = 0 \, 02083$)]. b. Fungsi Distribusi Kumulatif: $ F \( x \) = integral_(49 \, 75)^x 2 d t = 2 \( x - 49 \, 75 \) $ c.~$P \( X < 50 \, 1 \)$: $ P \( X < 50 \, 1 \) = F \( 50 \, 1 \) = 2 \( 50 \, 1 - 49 \, 75 \) = 0 \, 7 $ d.~$P \( 49 \, 9 < X < 50 \)$: $ P \( 49 \, 9 < X < 50 \) = F \( 50 \) - F \( 49 \, 9 \) = 0 \, 2 $

#emph[\(Bersumber dari penyelesaian probabilitas paket kimia seragam)].

#horizontalrule

== #strong[Soal 6]
<soal-6>
Ketebalan sebuah #emph[photoresist] yang diterapkan pada plat semiconductor manufaktur pada setiap bagian plat terdistribusi secara seragam antara 0,205 hingga 0,215 mikrometer. a. Tentukan fungsi distribusi kumulatif dari ketebalan #emph[photoresist] tersebut. b. Tentukan proporsi dari plat tersebut yang memiliki ketebalan #emph[photoresist] lebih besar dari 0,2125 mikrometer. c.~Berapa nilai ketebalan yang memiliki proporsi lebih besar dari 10% plat tersebut? d.~Tentukan nilai rata-rata dan variansi dari ketebalan #emph[photoresist] tersebut.

#strong[Jawaban:] a. Fungsi Distribusi Kumulatif: $ F \( x \) = 100 \( x - 0 \, 205 \) $ b. Proporsi $> 0 \, 2125$ mikrometer: $ P \( X > 0 \, 2125 \) = 1 - F \( 0 \, 2125 \) = 1 - 0 \, 75 = 0 \, 25 $ c.~Ketebalan untuk proporsi $> 10 %$: #emph[Terdapat 2 kemungkinan jawaban tergantung interpretasi kalimat:] Jawaban 1 (Batas atas 90%): $P \( X > x \) = 0 \, 9 arrow.r.double.long 0 \, 9 = 1 - 100 \( x - 0 \, 205 \) arrow.r.double.long x = 0 \, 206 upright(" mikrometer")$. Jawaban 2 (Batas atas 10%): $P \( X > x \) = 0 \, 1 arrow.r.double.long 0 \, 1 = 1 - 100 \( x - 0 \, 205 \) arrow.r.double.long x = 0 \, 214 upright(" mikrometer")$. d.~Nilai Rata-rata dan Variansi: $ mu = integral_(0 \, 205)^(0 \, 215) 100 x d x = 0 \, 210 $ $ sigma^2 = E \( X^2 \) - mu^2 = integral_(0 \, 205)^(0 \, 215) 100 x^2 d x - \( 0 \, 210 \)^2 = 8 \, 333 times 10^(- 6) $

#emph[\(Bersumber dari penyelesaian soal probabilitas ketebalan photoresist seragam)].

#horizontalrule

== #strong[Soal 7]
<soal-7>
Waktu yang dibutuhkan untuk sebuah sel melakukan pembelahan diri (mitosis) adalah terdistribusi normal pada sebuah rentang waktu 1 jam dengan standar deviasi 5 menit. a. Berapa probabilitas sebuah sel membelah dalam waktu kurang dari 45 menit? b. Berapa probabilitas sebuah sel membelah dengan membutuhkan waktu lebih dari 65 menit? c.~Berapa waktu yang dibutuhkan oleh setidaknya untuk 99% sel untuk melakukan mitosis secara sempurna?

#strong[Jawaban:] Diketahui $mu = 60 upright(" menit")$ dan $sigma = 5 upright(" menit")$. a. Probabilitas $< 45 upright(" menit")$: $ P \( X < 45 \) = P (Z < frac(45 - 60, 5)) = P \( Z < - 3 \) = 0 \, 00135 $ b. Probabilitas $> 65 upright(" menit")$: $ P \( X > 65 \) = 1 - P (Z < frac(65 - 60, 5)) = 1 - 0 \, 841345 = 0 \, 158655 $ c.~Waktu untuk setidaknya 99% sel: $ P \( X < x \) = 0 \, 99 arrow.r.double.long P \( Z < z \) = 0 \, 99 arrow.r.double.long z = 2 \, 326 $ $ x = mu + sigma z = 60 + 45 \( 2 \, 326 \) = 164 \, 67 upright(" menit") $ #emph[\(Sesuai dengan penulisan dan perhitungan referensi kunci jawaban asal)].

#emph[\(Bersumber dari penyelesaian kurva distribusi normal waktu mitosis)].

#horizontalrule

== #strong[Soal 8]
<soal-8>
Kekuatan komprehensif dari sampel semen dapat dimodelkan dalam sebuah distribusi normal dengan nilai rata-rata 6.000 $upright("kg/cm")^2$ dan standar deviasi sebesar 100 $upright("kg/cm")^2$. a. Berapa probabilitas untuk kekuatan sampel tersebut kurang dari 6250 $upright("kg/cm")^2$? b. Berapa probabilitas untuk kekuatan sampel tersebut di antara 5800 hingga 5900 $upright("kg/cm")^2$? c.~Berapa kekuatan yang dimiliki oleh lebih dari 95% sampel semen tersebut?

#strong[Jawaban:] a. Probabilitas $< 6250$: $ P \( X < 6250 \) = P (Z < frac(6250 - 6000, 100)) = P \( Z < 2 \, 5 \) = 0 \, 99379 $ b. Probabilitas antara 5800 dan 5900: $ P \( 5800 < X < 5900 \) = P (frac(5800 - 6000, 100) < Z < frac(5900 - 6000, 100)) = P \( - 2 < Z < - 1 \) = 0 \, 135905 $ c.~Kekuatan lebih dari 95% sampel: $ P \( X > x \) = 0 \, 95 arrow.r.double.long P \( Z > z \) = 0 \, 95 arrow.r.double.long z = - 1 \, 644 $ $ x = mu + sigma z = 6000 + 100 \( - 1 \, 644 \) = 5835 \, 515 upright(" kg/cm")^2 $ Setidaknya 95% sampel semen tersebut akan memiliki kekuatan di atas $5835 \, 515 upright(" kg/cm")^2$.

#emph[\(Bersumber dari standarisasi distribusi normal pada kekuatan semen)].

#horizontalrule

== #strong[Soal 9]
<soal-9>
Sebuah proses manufaktur #emph[chip] semikonduktor memproduksi setidaknya 2% #emph[chip] yang cacat. Asumsikan setiap #emph[chip] independen. Dari 1000 #emph[chip]: (gunakan pendekatan normal untuk binomial) a. Perkirakan probabilitas bahwa lebih dari 25 #emph[chips] cacat. b. Perkirakan probabilitas bahwa #emph[chip] yang cacat berjumlah antara 20 hingga 30 #emph[chip].

#strong[Jawaban:] Pendekatan normal untuk binomial: $mu = n p = 1000 \( 0 \, 02 \) = 20$ $sigma^2 = n p q = 1000 \( 0 \, 02 \) \( 0 \, 98 \) = 19 \, 6 arrow.r.double.long sigma = 4 \, 427189$ a. Lebih dari 25 #emph[chips] cacat: $ P \( X > 25 \) = P (Z > frac(25 - 20, 4 \, 427189)) = 0 \, 399322 $ b. Antara 20 hingga 30 #emph[chips] cacat: $ P \( 20 < X < 30 \) = P (frac(20 - 20, 4 \, 427189) < Z < frac(30 - 20, 4 \, 427189)) = 0 \, 195046 $

#emph[\(Bersumber dari aproksimasi kurva normal terhadap proses binomial pada manufaktur chip)].

#horizontalrule

== #strong[Soal 10]
<soal-10>
Misalkan jumlah partikel asbes dalam sampel 1 sentimeter kuadrat debu adalah random variable Poisson dengan nilai rata-rata 1000. Berapa probabilitas bahwa 10 sentimeter kuadrat debu mengandung lebih dari 10.000 partikel? Gunakan pendekatan normal!

#strong[Jawaban:] $lambda t = 1000 times 10 = 10000$ Pendekatan normal ke Poisson: $mu = 10000$, $sigma = sqrt(10000) = 100$ $ P \( X > 10000 \) = 1 - P \( X < 10000 \) = 1 - P (Z < frac(10000 - 10000, 100)) = 1 - 0 \, 5 = 0 \, 5 $

#emph[\(Bersumber dari aproksimasi normal terhadap proses Poisson dengan tingkat lambda tinggi)].

#horizontalrule

== #strong[Soal 11]
<soal-11>
Umur dari regulator voltase mobil memiliki distribusi eksponensial dengan umur rata-rata 6 tahun. Misalkan kamu membeli sebuah mobil dengan umur tepat 6 tahun, dengan regulator voltase yang terus bekerja, dan kamu merencanakan untuk menggunakan mobil itu hingga 6 tahun ke depan. a. Berapa probabilitas untuk regulator voltase mobil tersebut mengalami kegagalan pada saat dalam kepemilikanmu? b. Jika regulatormu mengalami kegagalan setelah 3 tahun kepemilikanmu dan kemudian diganti, berapa rata-rata waktu hingga kegagalan selanjutnya?

#strong[Jawaban:] a. Misalkan $X$ adalah umur dari regulator voltase mobil. Distribusi eksponensial bersifat tidak memiliki ingatan/memori (#emph[memoryless]), sehingga $beta = 6$. $ P \( X < 6 \) = 1 - e^(- x \/ beta) = 1 - e^(- 6 \/ 6) = 0 \, 63212 $ b. Karena distribusi tidak mempunyai ingatan, rata-rata kegagalan selanjutnya konstan: $ E \( X \) = beta = 6 upright(" tahun") $

#emph[\(Bersumber dari studi kasus kelangsungan fungsi komponen dengan memoryless property)].

#horizontalrule

== #strong[Soal 12]
<soal-12>
Waktu untuk mengalami kegagalan (dalam satuan jam) sebuah kipas pada PC dapat dimodelkan dengan distribusi eksponensial dengan nilai $lambda = 0 \, 0003$. a. Berapa proporsi dari probabilitas kipas tersebut akan bertahan setidaknya 10.000 jam? b. Berapa proporsi dari probabilitas kipas tersebut akan bertahan paling lama 7.000 jam saja?

#strong[Jawaban:] Fungsi Densitas $f \( x \) = lambda e^(- lambda x)$ dan $F \( x \) = 1 - e^(- lambda x)$. a. Bertahan setidaknya 10.000 jam: $ P \( X > 10000 \) = 1 - P \( X lt.eq 10000 \) = 1 - F \( 10000 \) = 1 - \( 1 - e^(- 0 \, 0003 \( 10000 \)) \) = 0 \, 04979 $ b. Bertahan paling lama 7.000 jam: $ P \( X lt.eq 7000 \) = F \( 7000 \) = 1 - e^(- 0 \, 0003 \( 7000 \)) = 0 \, 877543 $

#emph[\(Bersumber dari perhitungan fungsi kelangsungan hidup komponen kipas menggunakan parameter lambda)].

#horizontalrule

== #strong[Soal 13]
<soal-13>
Waktu antara kegagalan sebuah laser dalam mesin sitogenik terdistribusi secara eksponensial dengan rata-rata 25.000 jam. a. Tentukan variansi dari waktu antara kegagalan sebuah laser! b. Berapa prakiraan waktu hingga kegagalan kedua? c.~Berapa probabilitas bahwa waktu hingga mencapai kegagalan ketiga lebih dari 50.000 jam?

#strong[Jawaban:] a. $beta = mu = 25000 arrow.r.double.long sigma^2 = beta^2 = \( 25000 \)^2 = 6 \, 25 times 10^8$. b. Misalkan $X_1$ adalah kegagalan pertama dan $X_2$ kegagalan kedua. Karena bersifat eksponensial dan independen: $ E \( X_1 + X_2 \) = E \( X_1 \) + E \( X_2 \) = 25000 + 25000 = 50.000 upright(" jam") $ c.~Waktu kegagalan ke-$n$ mengikuti #strong[Distribusi Erlang]: $ P \( X_1 + X_2 + X_3 > 50000 \) = 1 - integral_0^50000 frac(\( 1 / 25000 \)^3 t^2 e^(- t \/ 25000), \( 3 - 1 \) !) d t = 1 - 0 \, 323324 = 0 \, 676676 $

#emph[\(Bersumber dari hubungan distribusi eksponensial, theorema linearitas ekspektasi, dan integral Erlang)].

#horizontalrule

== #strong[Soal 14]
<soal-14>
Error yang diakibatkan oleh kontaminasi pada kepingan optik muncul dengan kecepatan 1 error setiap $10^5$ bits. Asumsikan nilai error mengikuti distribusi Poisson. a. Berapa nilai rata-rata bilangan bit hingga 5 error muncul? b. Berapa standar deviasi dari bilangan bit hingga 5 error muncul? c.~Kode koreksi error kemungkinan tidak akan efektif jika ada 3 atau lebih error dalam rentang $10^5$ bit. Berapa besar probabilitas terjadinya momen ini?

#strong[Jawaban:] a. Distribusi Erlang digunakan dengan $r = 5$ dan $lambda = 10^(- 5)$: $ mu = r / lambda = 5 / 10^(- 5) = 5 times 10^5 upright(" bits") $ b. Varian ($sigma^2$): $ sigma^2 = r / lambda^2 = 5 times 10^10 upright(" bits")^2 $ #emph[\(Catatan referensi menyatakan hasil variansi secara langsung tanpa pengakaran standar deviasi)]. c.~Menggunakan variabel Poisson dalam jangkauan $10^5$ bits ($lambda t = 1 upright(" error")$): $ P \( X gt.eq 3 \) = 1 - P \( X < 3 \) = 1 - sum_(x = 0)^2 frac(e^(- 1) 1^x, x !) = 0 \, 0803 $

#emph[\(Bersumber dari transisi proses kejadian diskrit (Poisson) ke ruang waktu kontinu (Erlang))].

#horizontalrule

== #strong[Soal 15]
<soal-15>
Asumsikan umur dari paket keping magnetik terkena gas korosif memiliki distribusi Weibull dengan nilai $beta = 0 \, 5$ dan rata-rata umurnya ialah 600 jam. a. Tentukan probabilitas bahwa paket kepingan tersebut bertahan setidaknya 500 jam. b. Tentukan probabilitas bahwa paket kepingan tersebut mengalami kegagalan sebelum 400 jam.

#strong[Jawaban:] Misalkan parameter Weibull adalah $alpha$ dan $beta$. $ mu = alpha^(- 1 \/ beta) Gamma \( 1 + 1 \/ beta \) arrow.r.double.long 600 = alpha^(- 1 \/ 0 \, 5) Gamma \( 1 + 1 \/ 0 \, 5 \) $ $ 600 = alpha^(- 2) Gamma \( 3 \) = alpha^(- 2) \( 2 ! \) arrow.r.double.long alpha = frac(1, 10 sqrt(3)) = 0 \, 05773 $ a. Probabilitas bertahan $> 500$: $ P \( X > 500 \) = 1 - P \( X < 500 \) = 1 - \( 1 - e^(- alpha x^beta) \) = e^(- alpha 500^(0 \, 5)) = 0 \, 275028 $ b. Probabilitas gagal $< 400$: $ P \( X < 400 \) = 1 - e^(- alpha \( 400 \)^(0 \, 5)) = 0 \, 684816 $

#emph[\(Bersumber dari pencarian parameter sebaran Weibull menggunakan sifat relasi Fungsi Gamma dan invers fungsi kelangsungan hidup)].

#horizontalrule

== #strong[Soal 16]
<soal-16>
Jika $X$ adalah variabel random Weibull dengan $beta = 1$ dan $sigma = 1000$, apa nama lain dari distribusi variabel $X$ dan berapa nilai mean dari $X$?

#strong[Jawaban:] Distribusi dari random variable $X$ jika $beta = 1$ tereduksi murni menjadi #strong[distribusi eksponensial]. Dalam hal ini, parameter skalarnya ekuivalen: $ mu = sigma = 1000 $

#emph[\(Bersumber dari sifat asimtotik konversi bentuk antar kelompok keluarga eksponensial)].

#horizontalrule

== #strong[Soal 17]
<soal-17>
Misalkan bahwa jumlah km suatu mobil bisa melaju sampai akinya habis adalah berdistribusi eksponensial dengan mean 10.000 km. Jika seseorang ingin melakukan perjalanan 5.000 km, berapa probabilitas dia bisa menyelesaikan perjalanannya tanpa harus mengganti akinya?

#strong[Jawaban:] Misalkan $X$ adalah jumlah km suatu mobil bisa melaju sampai akinya habis. $beta = 10000$. Probabilitas tidak gagal selama perjalanan 5.000 km: $ P \( X > 5000 \) = 1 - \( 1 - e^(- 5000 \/ 10000) \) = e^(- 0 \, 5) = 0 \, 606530659 $

#emph[\(Bersumber dari evaluasi fungsi kelangsungan hidup tanpa ingatan pada uji ketahanan komponen)].
