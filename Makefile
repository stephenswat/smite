# Executables used to generate plots.
PYTHON=python3
GNUPLOT=gnuplot

# Precision settings.
EPSILON=0.000001

# Settings for the size of the figures; to find this, put `\the\linewidth` in a
# LaTeX figure, then divide that number (in pt) by 72.27.
FIGURE_WIDTH=3.335in

# Modifying the following variables may void the warranty.
PLOT_NAMES=overhead_acts_prop distribution_acts_prop combined result_binom_40_050_16 \
	result_geo_005_8 result_nbinom_5_030_4 result_pois_30_32 \
	result_uniform_20_40_2
DEGREES_OF_PARALLELISM=2 4 8 16 32
MODEL_NAMES=binom_40_050 geo_005 nbinom_5_030 pois_30 uniform_20_40
MODEL_DIR=data/models
MEASUREMENT_DIR=data/measurements
OUTPUT_DIR=output
OUTPUT_TABLE_DIR=$(OUTPUT_DIR)/tables
OUTPUT_TEX_PLOT_DIR=$(OUTPUT_DIR)/plots/tex
OUTPUT_PDF_PLOT_DIR=$(OUTPUT_DIR)/plots/pdf
TMP_DIR=tmp
MODEL_DEGREES=$(foreach t,$(DEGREES_OF_PARALLELISM),$(addsuffix _$(t),$(m)))
ALL_MODELS=$(foreach m,$(MODEL_NAMES),$(MODEL_DEGREES))

# Public-facing targets.
all: figures tables

figures: directories tex_plots

tables: directories $(OUTPUT_TABLE_DIR)/comparison_table.tex $(OUTPUT_TABLE_DIR)/miniapp_table.tex

tex_plots: directories $(OUTPUT_TEX_PLOT_DIR) $(addsuffix .tex,$(addprefix $(OUTPUT_TEX_PLOT_DIR)/,$(PLOT_NAMES)))

pdf_plots: directories $(OUTPUT_PDF_PLOT_DIR) $(addsuffix .pdf,$(addprefix $(OUTPUT_PDF_PLOT_DIR)/,$(PLOT_NAMES)))

all_pdf_plots: directories pdf_plots $(addsuffix .pdf,$(addprefix $(OUTPUT_PDF_PLOT_DIR)/result_,$(ALL_MODELS)))

# Internal targets. Here be dragons.
all_models: directories $(MODEL_DIR) $(addprefix $(MODEL_DIR)/model_,$(addsuffix .csv,$(ALL_MODELS))) $(foreach t,$(DEGREES_OF_PARALLELISM),$(MODEL_DIR)/model_acts_prop_$(t).csv)

directories: $(MODEL_DIR) $(TMP_DIR) $(MEASUREMENT_DIR) $(OUTPUT_TABLE_DIR) $(OUTPUT_TEX_PLOT_DIR) $(OUTPUT_PDF_PLOT_DIR)

$(TMP_DIR):
	mkdir -p $@

$(MODEL_DIR):
	mkdir -p $@

$(MEASUREMENT_DIR):
	mkdir -p $@

$(OUTPUT_TABLE_DIR):
	mkdir -p $@

$(OUTPUT_TEX_PLOT_DIR):
	mkdir -p $@

$(OUTPUT_PDF_PLOT_DIR):
	mkdir -p $@

$(OUTPUT_TABLE_DIR)/comparison_table.tex: python/create_mean_table.py all_models
	$(PYTHON) $< $@

$(OUTPUT_TABLE_DIR)/miniapp_table.tex: python/create_miniapp_table.py $(MODEL_DIR)/model_acts_prop_2.csv $(MODEL_DIR)/model_acts_prop_4.csv $(MODEL_DIR)/model_acts_prop_8.csv $(MODEL_DIR)/model_acts_prop_16.csv $(MODEL_DIR)/model_acts_prop_32.csv
	$(PYTHON) $< $(filter-out $<,$^) $@

$(MODEL_DIR)/model_acts_prop_%.csv: python/create_model.py data/acts/acts_prop_freq.csv
	$(PYTHON) $< -e $(EPSILON) -p $* file $(word 2, $^) $@

$(MODEL_DIR)/model_binom_40_050_%.csv: python/create_model.py
	$(PYTHON) $< -e $(EPSILON) -p $* binomial 40 0.5 $@

$(MODEL_DIR)/model_geo_005_%.csv: python/create_model.py
	$(PYTHON) $< -e $(EPSILON) -p $* geometric 0.05 $@

$(MODEL_DIR)/model_nbinom_5_030_%.csv: python/create_model.py
	$(PYTHON) $< -e $(EPSILON) -p $* nbinomial 5 0.3 $@

$(MODEL_DIR)/model_pois_30_%.csv: python/create_model.py
	$(PYTHON) $< -e $(EPSILON) -p $* poisson 30 $@

$(MODEL_DIR)/model_uniform_20_40_%.csv: python/create_model.py
	$(PYTHON) $< -e $(EPSILON) -p $* uniform 20 40 $@

$(TMP_DIR)/horizontal_%.csv: python/create_horizontal.py $(MODEL_DIR)/model_%_2.csv $(MODEL_DIR)/model_%_4.csv $(MODEL_DIR)/model_%_8.csv $(MODEL_DIR)/model_%_16.csv $(MODEL_DIR)/model_%_32.csv
	$(PYTHON) $< $(filter-out $<,$^) $@

$(TMP_DIR)/histogram_%.csv: python/create_graph_histogram.py $(MODEL_DIR)/model_%.csv $(MEASUREMENT_DIR)/data_%.csv
	$(PYTHON) $< $(filter-out $<,$^) $@

$(OUTPUT_TEX_PLOT_DIR)/overhead_%.tex: gnuplot/horizontal.gnuplot $(TMP_DIR)/horizontal_%.csv
	$(GNUPLOT) -e "figure_width='$(FIGURE_WIDTH)'" -e "input_file='$(word 2, $^)'" -e "output_file='$(notdir $@)'" $<
	mv $(notdir $@) $@
	mv $(patsubst %.tex,%.eps,$(notdir $@)) $(patsubst %.tex,%.eps,$@)

$(OUTPUT_TEX_PLOT_DIR)/distribution_%.tex: gnuplot/pmf_single.gnuplot data/acts/%_freq.csv
	$(GNUPLOT) -e "figure_width='$(FIGURE_WIDTH)'" -e "input_file='$(word 2, $^)'" -e "output_file='$(notdir $@)'" $<
	mv $(notdir $@) $@
	mv $(patsubst %.tex,%.eps,$(notdir $@)) $(patsubst %.tex,%.eps,$@)

$(OUTPUT_TEX_PLOT_DIR)/combined.tex: gnuplot/pmf.gnuplot
	$(GNUPLOT) -e "figure_width='$(FIGURE_WIDTH)'" -e "output_file='$(notdir $@)'" $<
	mv $(notdir $@) $@
	mv $(patsubst %.tex,%.eps,$(notdir $@)) $(patsubst %.tex,%.eps,$@)

$(OUTPUT_TEX_PLOT_DIR)/result_%.tex: gnuplot/results.gnuplot $(TMP_DIR)/histogram_%.csv
	$(GNUPLOT) -e "figure_width='$(FIGURE_WIDTH)'" -e "input_file='$(word 2, $^)'" -e "output_file='$(notdir $@)'" $<
	mv $(notdir $@) $@
	mv $(patsubst %.tex,%.eps,$(notdir $@)) $(patsubst %.tex,%.eps,$@)

$(OUTPUT_PDF_PLOT_DIR)/overhead_%.pdf: gnuplot/horizontal.gnuplot $(TMP_DIR)/horizontal_%.csv
	$(GNUPLOT) -e "render_pdf=1" -e "figure_width='$(FIGURE_WIDTH)'" -e "input_file='$(word 2, $^)'" -e "output_file='$@'" $<

$(OUTPUT_PDF_PLOT_DIR)/distribution_%.pdf: gnuplot/pmf_single.gnuplot data/acts/%_freq.csv
	$(GNUPLOT) -e "render_pdf=1" -e "figure_width='$(FIGURE_WIDTH)'" -e "input_file='$(word 2, $^)'" -e "output_file='$@'" $<

$(OUTPUT_PDF_PLOT_DIR)/combined.pdf: gnuplot/pmf.gnuplot
	$(GNUPLOT) -e "render_pdf=1" -e "figure_width='$(FIGURE_WIDTH)'" -e "input_file='$(word 2, $^)'" -e "output_file='$@'" $<

$(OUTPUT_PDF_PLOT_DIR)/result_%.pdf: gnuplot/results.gnuplot $(TMP_DIR)/histogram_%.csv
	$(GNUPLOT) -e "render_pdf=1" -e "figure_width='$(FIGURE_WIDTH)'" -e "input_file='$(word 2, $^)'" -e "output_file='$@'" $<

.SECONDARY: