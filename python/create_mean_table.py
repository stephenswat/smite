import argparse

import pandas
import numpy
import scipy.stats

from common import *

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create a descriptive comparison table."
    )

    parser.add_argument(
        "output",
        type=str,
        help="output file to write histogram to",
    )

    args = parser.parse_args()

    with open(args.output, "w") as of:
        of.write(
            "\\begin{tabular}{l r R{\\statcolwidth} R{\\statcolwidth} R{\\statcolwidth} R{\\statcolwidth} R{\\statcolwidth} R{\\statcolwidth}}\n"
        )
        of.write("\\toprule\n")
        of.write(
            "& & \\multicolumn{2}{c}{Modelled} & \\multicolumn{2}{c}{Simulated} & \\multicolumn{2}{c}{Measured} \\\\\n"
        )
        of.write("\\cmidrule(lr){3-4}\\cmidrule(lr){5-6}\\cmidrule(lr){7-8}\n")
        of.write(
            "Dist. & $n$ & \\multicolumn{1}{c}{$\\mu_A$} & \\multicolumn{1}{c}{$\\eta_{\\mu_S}$} & \\multicolumn{1}{c}{$\\mu_S$} & \\multicolumn{1}{c}{$\\eta_{\\mu_M}$} & \\multicolumn{1}{c}{$\\mu_M$} & \\multicolumn{1}{c}{$\\eta_{\\mu_A}$} \\\\\n"
        )
        of.write("\\midrule\n")

        for (f, d) in [
            ("\\distbinom{40}{0.5}", "binom_40_050"),
            ("\\distgeo{0.05}", "geo_005"),
            ("\\distpois{30}", "pois_30"),
            ("\\distuni{20}{40}", "uniform_20_40"),
            ("\\distnbinom{5}{0.3}", "nbinom_5_030"),
        ]:
            for n in [2, 4, 8, 16, 32]:
                mod_df = pandas.read_csv("data/models/model_%s_%d.csv" % (d, n))
                mod_df["value"] = mod_df["n"] / mod_df["d"]
                data_df = pandas.read_csv("data/measurements/synced/%s_%d.csv" % (d, n))
                data_df["sim_value"] = data_df["sim_simt"] / data_df["sim_mimt"]
                data_df["mea_value"] = data_df["mea_simt"] / data_df["mea_mimt"]

                meanA = (mod_df["value"] * mod_df["p"]).sum()
                meanS = (data_df["sim_value"]).mean()
                meanM = (data_df["mea_value"]).mean()

                of.write(
                    "% 24s & % 3d & %.3f & %.2f\\%% & %.3f & %.2f\\%% & %.3f & %.2f\\%%\\\\\n"
                    % (
                        ("$" + f + "$") if n == 2 else "",
                        n,
                        meanA,
                        100.0 * abs((meanS - meanA) / meanS),
                        meanS,
                        100.0 * abs((meanM - meanS) / meanM),
                        meanM,
                        100.0 * abs((meanA - meanM) / meanA),
                    )
                )

        of.write("\\bottomrule\n")
        of.write("\\end{tabular}\n")
