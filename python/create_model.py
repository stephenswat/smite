import itertools
import collections
import fractions
import csv
import argparse

import pandas
import scipy.stats
import numpy
import tqdm

from common import *


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create a model for a given distribution ."
    )

    parser.add_argument(
        "distribution",
        choices=[
            "binomial",
            "uniform",
            "nbinomial",
            "poisson",
            "geometric",
            "bernoulli",
            "file",
        ],
        help="distribution to create a model for",
    )
    parser.add_argument(
        "parameters",
        type=str,
        nargs="*",
        help="parameters for the given distribution",
    )
    parser.add_argument(
        "output",
        type=str,
        help="output file to write histogram to",
    )
    parser.add_argument(
        "-p",
        "--parallel",
        type=int,
        default=1,
        help="degree of parallelism",
    )

    parser.add_argument(
        "-e",
        "--epsilon",
        type=float,
        default=0.0001,
        help="epsilon factor for trimming infinite distributions",
    )

    args = parser.parse_args()

    if args.distribution == "binomial":
        d = scipy.stats.binom(
            int(args.parameters[0]),
            float(args.parameters[1]),
        )
    elif args.distribution == "uniform":
        d = scipy.stats.randint(
            int(args.parameters[0]),
            int(args.parameters[1]) + 1,
        )
    elif args.distribution == "nbinomial":
        d = scipy.stats.nbinom(
            int(args.parameters[0]),
            float(args.parameters[1]),
        )
    elif args.distribution == "geometric":
        d = scipy.stats.geom(
            float(args.parameters[0]),
        )
    elif args.distribution == "poisson":
        d = scipy.stats.poisson(
            float(args.parameters[0]),
        )
    elif args.distribution == "bernoulli":
        d = scipy.stats.binom(
            1,
            float(args.parameters[0])
        )
    elif args.distribution == "file":
        df = pandas.read_csv(args.parameters[0])
        d = scipy.stats.rv_discrete(values=(df["n"], df["p"]))

    print("Creating model from %s with %d parallel items..." % (repr(d), args.parallel))

    model = Hratio(d, args.parallel, epsilon=args.epsilon)

    with open(args.output, "w") as f:
        w = csv.DictWriter(f, fieldnames=["n", "d", "p"])

        w.writeheader()

        for (f, p) in sorted(model.items(), key=lambda x: x[0]):
            w.writerow({"n": f.numerator, "d": f.denominator, "p": p})
