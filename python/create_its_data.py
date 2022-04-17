import argparse

import pandas
import numpy
import scipy.stats

from common import *

def relErr(a, b):
    return abs((a - b) / a)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create an ITS comparison dataset."
    )

    parser.add_argument(
        "output",
        type=str,
        help="output file to write to",
    )

    args = parser.parse_args()

    output_dict = {}

    for (f, d) in [
        ("\\distbinom{40}{0.5}", "binom_40_050"),
        ("\\distgeo{0.05}", "geo_005"),
        ("\\distpois{30}", "pois_30"),
        ("\\distuni{20}{40}", "uniform_20_40"),
        ("\\distnbinom{5}{0.3}", "nbinom_5_030"),
    ]:
        for n in [2, 4, 8, 16, 32]:
            data_s_df = pandas.read_csv("data/measurements/synced/%s_%d.csv" % (d, n))
            data_s_df["mea_value"] = data_df["mea_simt"] / data_df["mea_mimt"]

            data_u_df = pandas.read_csv("data/measurements/unsynced/%s_%d.csv" % (d, n))
            data_u_df["mea_value"] = data_df["mea_simt"] / data_df["mea_mimt"]

            meanS = (data_s_df["mea_value"]).mean()
            meanU = (data_u_df["mea_value"]).mean()

            output_dict[(f, n)] = relErr(meanS, meanU)

    print(output_dict)
