figure_height='0.8in'

if (!exists("render_pdf")) {
    render_pdf = 0
}

if (render_pdf) {
    set terminal pdf size figure_width,figure_height
} else {
    set terminal epslatex size figure_width,figure_height
}

set datafile separator ","
set lmargin at screen 0.15
set rmargin at screen 0.98
set tmargin at screen 0.9
set bmargin at screen 0.2
set ytics 0.02
set key samplen 0.5
set key spacing 0.75
set xrange [1:]
set ylabel "$P\\left(\\mathcal{H}(w) = x\\right)$" offset 2

set output output_file
plot input_file u 1:2 every ::1 w steps lw 2 lc "#e41a1c" title "Modelled",\
    "" u 1:3 every ::1 w steps lw 2 lc "#377eb8" title "Simulated",\
    "" u 1:4 every ::1 w steps lw 2 lc "#4daf4a" title "Measured"
