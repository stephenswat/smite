figure_height='1in'

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

set ylabel "$f_\\mathrm{Acts}(x)$" offset 2
set ytics 0.02

set output output_file
plot input_file u 1:2 every ::1 w histeps lw 2 lc "#e41a1c" notitle
