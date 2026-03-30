# Master Prompt untuk ChatGPT — Buku Random Variable untuk Mahasiswa Gen-Z

Anda adalah penulis buku ajar yang sangat kuat dalam:
1. probabilitas dan statistika,
2. pedagogi untuk mahasiswa teknik/informatika tingkat dua,
3. penulisan Quarto `.qmd`,
4. Python untuk simulasi, visualisasi, dan eksplorasi konsep,
5. pembelajaran berbasis konteks keputusan nyata.

## Tugas Utama
Tulislah sebuah buku ajar untuk mata kuliah **II-2111 Probabilitas Statistika** dengan fokus utama pada topik **Random Variable**. Buku ini ditujukan untuk **mahasiswa tingkat dua**, terutama dengan karakter belajar **Gen-Z**: cepat bosan pada abstraksi yang terlalu dini, tetapi sangat tertarik pada konteks nyata, visualisasi, simulasi, dan quick wins yang membuat mereka merasa “saya bisa”.

## Tujuan Pembelajaran Buku
Buku ini harus membantu mahasiswa:
1. memahami konsep **Random Variable** secara intuitif dan formal,
2. menghubungkan probabilitas dengan **pengambilan keputusan**,
3. menggunakan **Python** untuk eksplorasi, simulasi Monte Carlo, dan verifikasi,
4. memahami relasi antar distribusi dan fungsi random variable,
5. membangun pola pikir engineer/data scientist: memodelkan, menghitung, mensimulasikan, lalu mengambil keputusan.

## Prinsip Pedagogis yang WAJIB diikuti
Gunakan prinsip berikut secara konsisten di seluruh buku:

### 1. Python dulu, logika kemudian
Urutan pembelajaran utama:
- konteks masalah nyata,
- quick win dengan Python,
- observasi pola,
- intuisi,
- formalisasi matematis,
- aplikasi keputusan.

Jangan mulai subbab dengan definisi formal yang panjang tanpa konteks.

### 2. Decision-making oriented
Selalu bingkai materi sebagai alat untuk menjawab:
- keputusan apa yang harus dibuat,
- ketidakpastian apa yang dihadapi,
- random variable apa yang relevan,
- ukuran apa yang penting (ekspektasi, varians, peluang, quantile, dsb),
- bagaimana Python membantu.

### 3. KMQA Framework
Setiap topik utama harus mengikuti pola:

#### K — Konteks
Mulai dari konteks nyata, aplikatif, dan relevan bagi mahasiswa.

#### M — Model
Bangun model probabilistik dengan random variable, parameter, asumsi, dan bila perlu diagram.

#### Q — Questions
Ubah konteks menjadi pertanyaan berbasis model:
- pertanyaan konsep,
- pertanyaan hitungan,
- pertanyaan simulasi,
- pertanyaan keputusan.

#### A — Apply / Answer
Jawab dengan:
- simulasi Monte Carlo,
- Python (`random`, `numpy`, `scipy.stats`, `matplotlib`),
- perhitungan teoritis,
- interpretasi keputusan.

### 4. Story + Logic + Code
Setiap subbab harus memadukan:
- cerita/konteks,
- model/logika,
- kode Python,
- interpretasi.

### 5. Gen-Z friendly but academically solid
Gaya harus:
- hangat,
- cerdas,
- memotivasi,
- tidak menggurui,
- tidak kaku,
- tetap akademik dan sahih.

## Struktur Buku yang HARUS dibuat
Buat buku dalam **6 bab**, masing-masing ditulis sebagai **file Quarto `.qmd` terpisah**.

### File yang harus dihasilkan
- `index.qmd` atau `00-pengantar.qmd` bila diperlukan
- `01-pendahuluan-pengambilan-keputusan.qmd`
- `02-random-variable-umum.qmd`
- `03-distribusi-diskrit.qmd`
- `04-distribusi-kontinu.qmd`
- `05-random-variable-multivariat-dan-fungsi.qmd`
- `06-penutup.qmd`
- `_quarto.yml`

## Instruksi Format Output
Setiap file `.qmd` harus:
1. memakai YAML header Quarto,
2. memiliki judul bab yang jelas,
3. memuat subbab terstruktur,
4. memuat blok kode Python yang dapat dijalankan,
5. memuat narasi, rumus LaTeX, dan visualisasi,
6. cocok untuk dirender sebagai buku Quarto,
7. tidak hanya berupa outline; tulislah sebagai draft isi buku yang cukup kaya.

## Struktur internal setiap subbab
Setiap subbab idealnya mengandung urutan berikut:

1. **Pemantik / pertanyaan awal**
2. **Konteks keputusan**
3. **Quick win dengan Python**
4. **Intuisi konsep**
5. **Definisi formal dan notasi**
6. **Model dan rumus**
7. **Contoh hitung**
8. **Simulasi / visualisasi**
9. **Interpretasi hasil**
10. **Implikasi keputusan**
11. **Ringkasan poin inti**
12. **Latihan**

## Isi per Bab

### Bab 1 — Pendahuluan: Pengambilan Keputusan di Bawah Ketidakpastian
Tujuan bab:
- memperkenalkan probabilitas sebagai bahasa pengambilan keputusan,
- memperkenalkan random variable sebagai pemetaan dunia acak ke bilangan,
- menunjukkan pentingnya ekspektasi dan varians,
- menanamkan peran Python sebagai alat berpikir.

Gunakan kasus unggulan berikut dan tulis dengan pendekatan KMQA:

#### Kasus 1: Ekspektasi dan Varians pada Investasi
Dua pilihan investasi:
- A stabil,
- B bisa tinggi tetapi bisa jeblok.
Tunjukkan bahwa keputusan dewasa bukan hanya melihat rata-rata, tetapi juga risiko.

#### Kasus 2: Produk Cacat dan Quality Control
Probabilitas cacat 1%, ambil 100 unit.
Bandingkan Binomial dan Poisson, lalu arahkan ke keputusan QC.

#### Kasus 3: Garansi Produk
Umur lampu rata-rata 900 jam, simpangan baku 50 jam.
Hitung peluang rusak sebelum T dan gunakan itu untuk keputusan garansi.

#### Kasus 4: Fungsi Random Variable
Jika arus acak dan daya `P = I^2 R`, tunjukkan bagaimana fungsi nonlinear mengubah distribusi.

#### Kasus 5: Variance, Profit, dan Risiko Bangkrut
Perusahaan:
- biaya produksi per produk \$100,
- produksi 1000 produk/hari,
- penjualan acak mean 1000/hari,
- margin 10% per produk terjual,
- modal awal 1x, 2x, 3x biaya produksi harian.
Gunakan Monte Carlo dan tunjukkan bahwa variance besar dapat menyebabkan bangkrut walaupun expected profit positif.

#### Kasus 6: Klinik Gigi
Klinik buka 8 jam/hari.
- Satu dokter butuh rata-rata 30 menit/pasien,
- waktu layanan memoryless,
- pasien datang rata-rata 16/hari,
- dokter dibayar tetap \$350/hari,
- pasien membayar \$1/menit layanan,
- biaya operasional klinik \$200/hari.
Analisis:
- rata-rata pasien terlayani,
- histogram pasien terlayani per hari,
- distribusi profit per hari,
- dampak jika ada dua dokter.

### Bab 2 — Random Variable Umum
Isi:
- pemetaan event probabilistik ke garis bilangan,
- range,
- diskrit vs kontinu,
- PMF,
- CDF,
- PDF,
- ekspektasi,
- varians,
- simpangan baku.

### Bab 3 — Distribusi Random Variable Diskrit
Isi:
- distribusi custom dari histogram,
- discrete uniform,
- Bernoulli,
- Binomial,
- Geometric,
- Poisson.

Untuk setiap distribusi:
- konteks,
- parameter,
- Python manual,
- Python `scipy.stats`,
- plot PMF/CDF,
- contoh keputusan,
- kapan distribusi itu cocok digunakan.

### Bab 4 — Distribusi Random Variable Kontinu
Isi:
- distribusi custom dari tabel selang/trapezoid,
- uniform kontinu,
- normal dan hubungannya dengan binomial,
- gamma,
- eksponensial dan hubungannya dengan Poisson process,
- erlang,
- weibull,
- pareto,
- chi-square.

Untuk setiap distribusi:
- intuisi bentuk,
- parameter,
- PDF/CDF,
- Python,
- Monte Carlo,
- keputusan nyata.

### Bab 5 — Random Variable Multivariat dan Fungsi Random Variable
Isi:
- random variable bivariat diskrit,
- random variable bivariat kontinu,
- marginal,
- conditional,
- kovariansi,
- korelasi,
- independensi,
- fungsi random variable,
- transformasi peubah.

### Bab 6 — Penutup
Isi:
- ulangi prinsip utama buku,
- tekankan bahwa probabilitas adalah alat berpikir di bawah ketidakpastian,
- tegaskan hubungan model, Python, dan keputusan,
- tutup dengan nada inspiratif bagi mahasiswa.

## Instruksi Python
Gunakan Python dengan prioritas:
- `random`
- `numpy`
- `scipy.stats`
- `matplotlib`

Jika relevan, gunakan:
- `pandas`
- `math`

Semua kode harus:
- sederhana,
- jelas,
- bisa dijalankan di Quarto/Jupyter,
- diberi komentar singkat,
- modular bila perlu.

## Instruksi Diagram
Bila membantu, gunakan:
- Mermaid
- Graphviz

untuk menjelaskan model, alur keputusan, atau relasi antar distribusi.

## Instruksi Gaya Penulisan
Tulislah seperti dosen yang:
- paham kesulitan mahasiswa,
- sabar,
- memberi quick wins,
- tidak menyepelekan logika,
- membuat mahasiswa merasa bahwa topik ini bisa dikuasai.

## Instruksi Output Final
Keluarkan hasil dalam bentuk:
1. `_quarto.yml`
2. file `.qmd` terpisah untuk setiap bab

Tulis masing-masing file secara eksplisit dengan format berikut:

```text
=== FILE: _quarto.yml ===
...isi file...

=== FILE: 01-pendahuluan-pengambilan-keputusan.qmd ===
...isi file...

=== FILE: 02-random-variable-umum.qmd ===
...isi file...
```

dan seterusnya sampai seluruh file selesai.

Pastikan isi setiap file cukup kaya untuk menjadi draft buku yang nyata, bukan sekadar daftar poin.
