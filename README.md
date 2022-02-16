# Thread Divergence Overhead Artefact

This directory contains the complete code base to generate the model and plots
as they are shown in our paper _"Statistically Modelling the Overhead of Thread
Divergence in Variable Length SIMT Workloads"_. What follows is a description
of the dependencies of this artefact, its directory structure, the methodology to reproduce the
figures and tables from the paper, and the ways in which we can generate
arbitrary models.

## Dependencies

In order to re-produce the graphs in our paper, the following software is required:

* gnuplot
* python3

In order to re-generate the measurements from scratch, the following is
required:

* A working CUDA compiler (nvcc is recommended, clang is untested)
* A CUDA-capable graphics card

Please note that we require certain Python packages to be installed. These can
all be installed through pip, or any other Python package manager:

* tqdm
* pandas
* numpy
* scipy

Please note that this artefact has only been tested on Linux-based operating
systems. We are confident that the software will still work on Mac OS-based
systems. Microsoft Windows and other operating systems are not supported.

## Directory structure

The directory structure of this artifact is as follows; files marked with the
"†" symbol are transient, meaning that they can be repreduced if necessary, but
they are included because generating them is computationally costly or because
generating them requires hardware that may not be available to the reviewers
(in particular, a CUDA-capable NVIDIA graphics card):

* `cuda/`: Contains the code to generate the empirical measurements presented
  in the paper.
  * `CMakeLists.txt`: CMake-based build system to compile the software.
  * `main.cu`: Source code for our benchmark.
* `data/`: Contains transient and non-transient data, including models.
  * `acts/`: Contains data about the Acts propagation used as a real-world
    example in our paper.
    * `acts_prop_freq.csv`: Contains step count-probability pairs for the Acts
      propagation. In this file the column `n` denotes the number of
      propagation steps, and `p` denotes the probability. Thus, the line
      `45,0.05` indicates that there is a 0.05 probability that a particle will
      require exactly 45 steps.
  * `measurements/` †: Measured results taken on a GPU. Can be re-generated if
    the `cuda/` project can be built and if an NVIDIA GPU is available.
    * `data_XXX_YY.csv` †: Contains measurement data as well as simulation data
      for distribution `XXX` with `YY` concurrent parallel jobs. The column `i`
      is an index column, `sim_simt` is the SIMT cost of the Monte Carlo
      simulation, `sim_mimt` is the MIMD cost of the Monte Carlo simulation,
      `mea_simt` is the SIMT timing measured on the GPU, and `mea_mimt` is the
      MIMD timing measured on the same GPU.
  * `models/` †: Pre-computed models, can be re-generated using Python,
    although this may take some time.
    * `model_XXX_YY.csv` †: Contains modelled probabilities for distribution
      `XXX` with `YY` concurrent threads. The column `n` is the numerator, `d`
      is the denominator, and `p` is the propability. Thus, the line `5,3,0.15`
      indicates that an overhead of 1.667 has probability 0.15.
* `gnuplot/`: Plotting scripts to generate the plots shown in our paper.
  * `acts_distribution.gnuplot`: Produces Figure 6.
  * `acts_overhead.gnuplot`: Produces Figure 7.
  * `pmf.gnuplot`: Produces Figure 4.
  * `results.gnuplot`: Produces Figure 5.
* `python/`: Data-processing scripts that act as a pre-processing step to the
  plotting scripts (these scripts are explained in more detail later).
  * `__init__.py`: Declares a Python package.
  * `common.py`: Contains the common code used in all the scripts.
  * `create_graph_histogram.py`: Pre-processes data into histograms for
    plotting with `results.gnuplot`.
  * `create_horizontal.py`: Pre-process data into histograms for plotting with
    `acts_overhead.gnuplot`.
  * `create_model.py`: Used to re-create `data/models/`.
  * `create_table.py`: Used to generate Table 1.
* `.gitignore`: Helper file for the Git version control system.
* `Makefile`: Helper file used to programatically (re-)generate all the output
  files.
* `README.md`: This file.

## Re-production instructions

Reproducing the figures and tables from our paper should be as simple as
executing the following in the top-level directory:

```bash
$ make
```

Make can also run in a multi-threaded mode (using the `-j` flag). This should
work fine, although the progress bars displayed by the modelling programs may
become inelegantly intertwined.

Please note that Make regenerates files based on their modification date; we
have provided pre-computed models with this artefact to save computation time
if so desired. In case the modification times are not set properly (for
example, if they are lost in the archival process) and Make insists on
re-generating models, the modification dates for the models can be updated as
follows, after which re-running Make should use the pre-computed models:

```bash
$ touch -c data/models/*
```

Updating the modification date on the measured data is also possible, and may
prove useful if no CUDA GPU is available:

```bash
$ touch -c /data/measurements/*
```

### Resulting files

Re-producing the artefact produces the following files:

* `output/` †: Directory used to store all output graphs and tables.
  * `combined.{tex,eps,pdf}` †: Figure 4 in the paper.
  * `distribution_acts_prop.{tex,eps,pdf}` †: Figure 6 in the paper.
  * `overhead_acts_prop.{tex,eps,pdf}` †: Figure 7 in the paper.
  * `result_binom_40_050_16.{tex,eps,pdf}` †: Figure 5a in the paper.
  * `result_geo_005_8.{tex,eps,pdf}` †: Figure 5b in the paper.
  * `result_nbinom_5_030_4.{tex,eps,pdf}` †: Figure 5c in the paper.
  * `result_pois_30_32.{tex,eps,pdf}` †: Figure 5d in the paper.
  * `result_uniform_20_40_2.{tex,eps,pdf}` †: Figure 5e in the paper.

Each of the TeX files generated is accompanied by an EPS file. Unfortunately,
these plots are not complete without these two parts. This is a consequence of
how the `epslatex` terminal generates plots for LaTeX documents. For
convenience, we also output PDF files, which can be inspected as stand-alone
document. However, it must be noted that the PDF files are not representative
of what appears in the final document. For example, LaTeX math mode is not
rendered correctly in PDF documents; these should only be used for
surface-level visual inspection.

Please note that Table 1 relies on the chi-square goodness-of-fit test, which
is extremely sensitive to noise. It is likely that re-produced versions of this
table will have different goodness-of-fit values. This is to be expected; the
only consistent feature should be that the p-values should remain above 0.1,
meaning that we do not reject the hypothesis of the distributions being the
same.

### Troubleshooting

Writing re-producible artefacts for unknown systems is difficult, and although
we have done our best to make the re-production process as painless as
possible, things may go wrong.

In the file `Makefile`, the top lines can be configured; this may be useful if
the default executables for Python and gnuplot cannot be found.

### From-scratch re-production

The re-production steps listed above use the pre-generated models and
measurements provided by the authors. In order to truly re-produce the figures
and tables from scratch, delete the `data/models/` and `data/measurements/`
directories (as well as the `output/` directory) and re-run Make. Make should
automatically detect that the necessary transient files are missing and attempt
to re-generate them. Please note that this requires an NVIDIA GPU to be
present, and that re-generating the models may take some times. Individual
files from the `data/models/` and `data/measurements` directories may also be
deleted, and our Make system should be sufficiently robust to regenerate
whatever files are necessary.

## Creating new models
