import itertools
import collections
import fractions

import scipy.stats
import numpy
import pandas
import tqdm


def Hmax(d, n):
    sl, sh = d.support()

    xk = numpy.arange(sl, sh + 1)
    pk = [d.cdf(i) ** n - (d.cdf(i) - d.pmf(i)) ** n for i in xk]

    return scipy.stats.rv_discrete(name="max_dist", values=(xk, pk))


def Hfinite(d, t=0.01, allow_zero=True):
    sl, _ = d.support()
    lo = max(0 if allow_zero else 1, sl)

    for i in itertools.count():
        if d.cdf(i) >= (1 - t):
            hi = i
            break

    xk = numpy.arange(lo, hi + 1)

    cr = d.cdf(hi) - d.cdf(lo - 1)
    pk = [d.pmf(i) / cr for i in xk]

    return scipy.stats.rv_discrete(name="finite_dist", values=(xk, pk))


def Hsumwithmax(d, n, a):
    p = numpy.zeros((n + 1) * a + 1)
    p[0] = 1.0
    q = p.copy()
    dpmf = numpy.array([d.pmf(k) for k in range(a + 1)])

    for i in range(n):
        for j in range((i + 1) * a, -1, -1):
            p[j] = numpy.sum(
                p[(j - (min(j + 1, a + 1) - 1)) : j + 1][::-1]
                * dpmf[: min(j + 1, a + 1)]
            )
            q[j] = numpy.sum(
                q[(j - (min(j + 1, a) - 1)) : j + 1][::-1] * dpmf[: min(j + 1, a)]
            )

    pk = p - q
    xk = numpy.arange(0, len(pk))

    df = pandas.DataFrame(data={"n": xk, "p": pk})
    df["p"] = numpy.maximum(0, df["p"])
    df2 = df[(df["n"] >= a) & (df["n"] <= n * a)].copy()
    df2["p"] /= df2["p"].sum()

    if not numpy.isclose(df2["p"].sum(), 1.0):
        return None

    return scipy.stats.rv_discrete(
        name="sum_given_max_dist", values=(df2["n"], df2["p"])
    )


def Hratio(d, t, epsilon=0.0000001):
    _, supp_max = d.support()

    if numpy.isinf(supp_max):
        d = Hfinite(d, epsilon, allow_zero=True)

    max_dist = Hmax(d, t)

    pmap = collections.defaultdict(float)

    max_supp_min, max_supp_max = max_dist.support()

    for j in tqdm.tqdm(range(max_supp_min, max_supp_max + 1)):
        pj = max_dist.pmf(j)

        if j == 0:
            pmap[fractions.Fraction(0, 1)] += pj
            continue

        sum_dist = Hsumwithmax(d, t, j)

        if sum_dist is None:
            continue

        sum_supp_min, sum_supp_max = sum_dist.support()

        for k in tqdm.tqdm(range(sum_supp_min, sum_supp_max + 1), leave=False):
            pmap[fractions.Fraction(t * j, k)] += pj * sum_dist.pmf(k)

    assert numpy.isclose(sum(pmap.values()), 1.0)

    return pmap
