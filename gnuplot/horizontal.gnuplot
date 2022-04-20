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

set key samplen 0.5
set ytics 0.08
set key Left
set key width -4
#set xlabel "$x$" offset 0,0.5
set ylabel "$P\\left(\\mathcal{H}(w) = x\\right)$" offset 2

set output output_file
plot input_file u 1:2 every ::1 w steps lw 2 lc "#e41a1c" title "$|w| = 2$",\
     "" u 1:3 every ::1 w steps lw 2 lc "#377eb8" title "$|w| = 4$",\
     "" u 1:4 every ::1 w steps lw 2 lc "#4daf4a" title "$|w| = 8$",\
     "" u 1:5 every ::1 w steps lw 2 lc "#984ea3" title "$|w| = 16$",\
     "" u 1:6 every ::1 w steps lw 2 lc "#ff7f00" title "$|w| = 32$"
