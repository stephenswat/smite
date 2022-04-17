import argparse

import pandas
import numpy
import scipy.stats

from common import *

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create our mini-app table.")

    parser.add_argument(
        "m02",
        type=str,
        help="model file for n=2",
    )
    parser.add_argument(
        "m04",
        type=str,
        help="model file for n=2",
    )
    parser.add_argument(
        "m08",
        type=str,
        help="model file for n=2",
    )
    parser.add_argument(
        "m16",
        type=str,
        help="model file for n=2",
    )
    parser.add_argument(
        "m32",
        type=str,
        help="model file for n=2",
    )

    parser.add_argument(
        "output",
        type=str,
        help="output file to write histogram to",
    )

    args = parser.parse_args()

    with open(args.output, "w") as of:
        of.write("\\begin{tabular}{R{0.6cm} R{0.6cm} R{0.8cm} R{0.8cm} R{0.8cm}}\n")
        of.write("\\toprule\n")
        of.write(
            "Par.\\tnote{1} & Thr.\\tnote{2} & $h_d(n)$ & $h_p(n)$ & $h(n)$ \\\\ \\midrule\n"
        )

        dfs = {
            2: pandas.read_csv(args.m02),
            4: pandas.read_csv(args.m04),
            8: pandas.read_csv(args.m08),
            16: pandas.read_csv(args.m16),
            32: pandas.read_csv(args.m32),
        }

        means = {
            1: 1.0,
            2: numpy.average(dfs[2]["n"] / dfs[2]["d"], weights=dfs[2]["p"]),
            4: numpy.average(dfs[4]["n"] / dfs[4]["d"], weights=dfs[4]["p"]),
            8: numpy.average(dfs[8]["n"] / dfs[8]["d"], weights=dfs[8]["p"]),
            16: numpy.average(dfs[16]["n"] / dfs[16]["d"], weights=dfs[16]["p"]),
            32: numpy.average(dfs[32]["n"] / dfs[32]["d"], weights=dfs[32]["p"]),
        }

        parls = [1, 2, 4, 8, 16, 32]

        out_df = pandas.DataFrame(
            data={
                "par": parls,
                "thr": [32 // n for n in parls],
                "hdn": [means[n] for n in parls],
                "hpn": [(20 + (32 // n) * 1) / (20 + 1) for n in parls],
            }
        )

        out_df["h_n"] = out_df["hdn"] * out_df["hpn"]

        for _, r in out_df.iterrows():
            of.write(
                "%d & %d & %.3f & %.3f & {%s%.3f}\\\\\n"
                % (
                    r["par"],
                    r["thr"],
                    r["hdn"],
                    r["hpn"],
                    "\\bf " if numpy.isclose(r["h_n"], out_df["h_n"].min()) else "",
                    r["h_n"],
                )
            )

        of.write("\\bottomrule\n")
        of.write("\\end{tabular}\n")
