max(a,b) = a > b ? a : b
isint(x)=(int(x)==x)
uniform(x,a,b) = x >= a ? (x <= b ? (1.0 / (b - a + 1)) : 0) : 0
binom(x,n,p)=p<0.0||p>1.0||n<0||!isint(n)?1/0:  !isint(x)?1/0:x<0||x>n?0.0:exp(lgamma(n+1)-lgamma(n-x+1)-lgamma(x+1)  +x*log(p)+(n-x)*log(1.0-p))
poisson(x,mu)=mu<=0?1/0:!isint(x)?1/0:x<0?0.0:exp(x*log(mu)-lgamma(x+1)-mu)
geometric(x,p)=p<=0||p>1?1/0:  !isint(x)?1/0:x<0||p==1?(x==0?1.0:0.0):exp(log(p)+x*log(1.0-p))
negbin(x,r,p)=r<=0||!isint(r)||p<=0||p>1?1/0:  !isint(x)?1/0:x<0?0.0:p==1?(x==0?1.0:0.0):exp(lgamma(r+x)-lgamma(r)-lgamma(x+1)+  r*log(p)+x*log(1.0-p))

set style arrow 1 nohead lc "black"

figure_height='0.75in'

if (!exists("render_pdf")) {
    render_pdf = 0
}

if (render_pdf) {
    set terminal pdf size figure_width,figure_height
} else {
    set terminal epslatex size figure_width,figure_height
}

set output output_file
set yrange [0:0.15]
set xrange [0:40]
set xtics 0,10,50
set ylabel "$p(x)$" offset 2
set rmargin at screen 0.725
set tmargin at screen 0.98
set lmargin at screen 0.15
set bmargin at screen 0.2
set key outside right
set key samplen 0.5
set key spacing 0.75
set key Left
set key width -1
set ytics 0.03

f1(x) = binom(x, 40, 0.5)
f2(x) = geometric(x, 0.05)
f3(x) = poisson(x, 30)
f4(x) = uniform(x, 20, 40)
f5(x) = negbin(x, 5, 0.3)

plot sample \
     [t=0:80:1] "+" using (t):(0.0):(0.0):(max(f1(t), max(f2(t), max(f3(t), max(f5(t), f4(t)))))) with vectors arrowstyle 1 notitle,\
     [t=0:80:1] "+" using ($1):(f1($1)) with points lc "#e41a1c" ps 1 pointtype 5 title "$\\distbinom{40}{0.5}$",\
     [t=0:80:1] "+" using ($1):(f2($1)) with points lc "#377eb8" ps 1 pointtype 7 title "$\\distgeo{0.05}$",\
     [t=0:80:1] "+" using ($1):(f3($1)) with points lc "#4daf4a" ps 1.1 pointtype 9 title "$\\distpois{30}$",\
     [t=0:80:1] "+" using ($1):(f4($1)) with points lc "#984ea3" ps 1.1 pointtype 11 title "$\\distuni{20}{40}$",\
     [t=0:80:1] "+" using ($1):(f5($1)) with points lc "#ff7f00" ps 1.2 pointtype 13 title "$\\distnbinom{5}{0.3}$",\
