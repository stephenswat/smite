figure_height='3in'

if (!exists("render_pdf")) {
    render_pdf = 0
}

if (render_pdf) {
    set terminal pdf size figure_width,figure_height
} else {
    set terminal epslatex size figure_width,figure_height
}

set datafile separator ","
set key autotitle columnhead
set key outside
set lmargin at screen 0.16
set rmargin at screen 0.98
set tmargin at screen 0.68
set bmargin at screen 0.2
set key horizontal
set key Right
set key samplen 2
set key width -3

set ylabel "$\\eta$" offset 3
set format y "%.2f\\%%"
set ytics 0.25
set yrange [0:1]

set output output_file


set style data histogram
set style histogram cluster
set style fill solid border -1
set boxwidth 0.8
set xrange [-0.5:4.5]

plot input_file \
       u (100*$2):xtic(1) lc "#e41a1c" ti "$|w| = 2$", \
    '' u (100*$3):xtic(1) lc "#377eb8" ti "$|w| = 4$", \
    '' u (100*$4):xtic(1) lc "#4daf4a" ti "$|w| = 8$", \
    '' u (100*$5):xtic(1) lc "#984ea3" ti "$|w| = 16$", \
    '' u (100*$6):xtic(1) lc "#ff7f00" ti "$|w| = 32$"
