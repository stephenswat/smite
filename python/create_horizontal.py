import pandas
import numpy
import sys

NBINS = 50

if __name__ == "__main__":
    m02_file = sys.argv[1]
    m04_file = sys.argv[2]
    m08_file = sys.argv[3]
    m16_file = sys.argv[4]
    m32_file = sys.argv[5]
    output_file = sys.argv[6]

    df02 = pandas.read_csv(m02_file)
    df02["v"] = df02["n"] / df02["d"]
    df04 = pandas.read_csv(m04_file)
    df04["v"] = df04["n"] / df04["d"]
    df08 = pandas.read_csv(m08_file)
    df08["v"] = df08["n"] / df08["d"]
    df16 = pandas.read_csv(m16_file)
    df16["v"] = df16["n"] / df16["d"]
    df32 = pandas.read_csv(m32_file)
    df32["v"] = df32["n"] / df32["d"]

    bins = numpy.linspace(1.0, 3.0, NBINS + 1)

    h02, _ = numpy.histogram(df02["v"], bins=bins, weights=df02["p"])
    h04, _ = numpy.histogram(df04["v"], bins=bins, weights=df04["p"])
    h08, _ = numpy.histogram(df08["v"], bins=bins, weights=df08["p"])
    h16, _ = numpy.histogram(df16["v"], bins=bins, weights=df16["p"])
    h32, _ = numpy.histogram(df32["v"], bins=bins, weights=df32["p"])

    df_out = pandas.DataFrame(
        data={
            "bin": bins[:-1],
            "p02": h02,
            "p04": h04,
            "p08": h08,
            "p16": h16,
            "p32": h32,
        }
    )

    df_out.to_csv(output_file, index=False)
