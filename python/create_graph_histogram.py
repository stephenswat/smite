import pandas
import numpy
import argparse


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create a histogram joining a model and empirical data."
    )

    parser.add_argument(
        "model",
        type=str,
        help="model CSV file to use",
    )
    parser.add_argument(
        "data",
        type=str,
        help="empirical data CSV file to use",
    )
    parser.add_argument(
        "output",
        type=str,
        help="output file to write histogram to",
    )
    parser.add_argument(
        "-b",
        "--bins",
        type=int,
        default=50,
        help="number of bins to use in histogram",
    )
    parser.add_argument(
        "-l",
        "--limit",
        type=float,
        default=0.9995,
        help="model CDF at which to end the last bin",
    )
    parser.add_argument(
        "-o",
        "--offset",
        type=float,
        default=0.05,
        help="overhead ratio difference past the CDF at which to end binning",
    )

    args = parser.parse_args()

    df_model = pandas.read_csv(args.model)
    df_model["v"] = df_model["n"] / df_model["d"]
    df_model["cdf"] = df_model["p"].cumsum()

    df_model_f = df_model[df_model["cdf"] <= args.limit]

    df_data = pandas.read_csv(args.data)
    df_data["f_sim"] = df_data["sim_simt"] / df_data["sim_mimt"]
    df_data["f_mea"] = df_data["mea_simt"] / df_data["mea_mimt"]

    bins = numpy.linspace(1, df_model_f.iloc[-1]["v"] + args.offset, args.bins + 1)

    hist_model, _ = numpy.histogram(df_model["v"], bins=bins, weights=df_model["p"])
    hist_sim, _ = numpy.histogram(df_data["f_sim"], bins=bins)
    hist_sim_n = hist_sim.astype(numpy.float64) / numpy.sum(hist_sim)
    hist_mea, _ = numpy.histogram(df_data["f_mea"], bins=bins)
    hist_mea_n = hist_mea.astype(numpy.float64) / numpy.sum(hist_mea)

    df_out = pandas.DataFrame(
        data={
            "bin": bins[:-1],
            "mod": hist_model,
            "sim": hist_sim_n,
            "mea": hist_mea_n,
            "sim_n": hist_sim,
            "mea_n": hist_mea,
        }
    )

    df_out.to_csv(args.output, index=False)
