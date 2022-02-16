for d in {"uniform --low 20 --high 40","geometric --probability 0.05","poisson --lambda 30","binomial --trials 40 --probability 0.5","nbinomial --failures 5 --probability 0.3"}; do
    for t in {1,2,4,8,16,32}; do
        IFS=" "; read -A args <<< $d
        ../build/generate --distribution ${args[@]} -t $t
    done
done

for d in {"uniform_20_40","geo_005","binom_40_050","nbinom_5_030","pois_30"}; do
    for t in {2,4,8,16,32}; do
        PLOTNAME="${d}_${t}";
        python3 ../python/process_data.py ../models/model_${PLOTNAME}.csv ../data/data_${PLOTNAME}.csv plot_${PLOTNAME}.csv
    done
done
