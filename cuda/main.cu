#include <random>
#include <sstream>
#include <iostream>
#include <fstream>
#include <iomanip>

#include <cuda_runtime.h>

#include <boost/program_options.hpp>
#include <boost/log/trivial.hpp>

#define cudaErrorCheck(r) { _cudaErrorCheck((r), __FILE__, __LINE__); }

void _cudaErrorCheck(cudaError_t code, const char *file, int line)
{
    if (code != cudaSuccess) {
        std::stringstream ss;

        ss << "[" << file << ":" << line << "] CUDA error: " << cudaGetErrorString(code);

        throw std::runtime_error(ss.str());
    }
}

static constexpr int WARP_SIZE = 32;
static constexpr int MAT_DIM = 8;

/**
 * Calculate a = a * b;
 */
__device__ void mat_mul(float * a, float * b) {
    float tmp[MAT_DIM * MAT_DIM];

    for (uint i = 0; i < MAT_DIM; ++i) {
        for (uint j = 0; j < MAT_DIM; ++j) {
            tmp[i * MAT_DIM + j] = a[i * MAT_DIM + j];
        }
    }

    for (uint i = 0; i < MAT_DIM * MAT_DIM; ++i) {
        a[i] = 0.f;
    }

    for (uint i = 0; i < MAT_DIM; ++i) {
        for (uint j = 0; j < MAT_DIM; ++j) {
            for (uint k = 0; k < MAT_DIM; ++k) {
                a[MAT_DIM * i + j] += tmp[MAT_DIM * i + k] * b[MAT_DIM * k + j];
            }
        }
    }
}

template<bool Sync>
__global__ void kernel(uint tc, float * ms, float * os, uint * ps, uint * cs1, uint * cs2) {
    int gid = blockIdx.x;
    int tid = threadIdx.x + blockIdx.x * tc;
    int lid = threadIdx.x;

    if (lid >= tc) {
        return;
    }

    float acc[MAT_DIM * MAT_DIM];

    for (uint i = 0; i < MAT_DIM; ++i) {
        for (uint j = 0; j < MAT_DIM; ++j) {
            acc[i * MAT_DIM + j] = i == j ? 1.f : 0.f;
        }
    }

    float mat[MAT_DIM * MAT_DIM];

    for (uint i = 0; i < MAT_DIM * MAT_DIM; ++i) {
        mat[i] = ms[MAT_DIM * MAT_DIM * tid + i];
    }

    __syncthreads();

    uint t_start = clock64();
    uint t_mimt = clock64();
    
    if constexpr (Sync) {
        __syncwarp();
    }

    for (uint i = 0; i < ps[tid]; ++i) {
        mat_mul(acc, mat);
        if constexpr (Sync) {
            __syncwarp(__activemask());
        }
        t_mimt = clock64();
    }

    if constexpr (Sync) {
        __syncwarp();
    }

    uint t_simt = clock64();

    __syncthreads();

    for (uint i = 0; i < MAT_DIM * MAT_DIM; ++i) {
        os[MAT_DIM * MAT_DIM * tid + i] = acc[i];
    }

    __syncthreads();

    if (lid == 0) {
        cs1[gid] = 0;
        cs2[gid] = 0;
    }

    __syncthreads();

    atomicAdd(&cs1[gid], t_simt - t_start);
    atomicAdd(&cs2[gid], t_mimt - t_start);
}

template<template <typename> typename RNG, typename ...Args>
void generate_ps(uint * o, uint n, std::mt19937 & r, Args... args) {
    RNG<uint> pdis(std::forward<Args>(args)...);

    for (uint i = 0; i < n; ++i) {
        o[i] = pdis(r);
    }
}

void parse_opts(int argc, char* argv[], boost::program_options::variables_map & vm) {
    boost::program_options::options_description opts("general options");

    opts.add_options()
        (
            "help",
            "produce help message"
        )
        (
            "distribution,d",
            boost::program_options::value<std::string>()->required(),
            "distribution type to use (must be \"uniform\", \"binomial\", \"nbinomial\", \"poisson\", or \"geometric\")"
        )
        (
            "seed",
            boost::program_options::value<std::mt19937::result_type>(),
            "set seed for random number generators"
        )
        (
            "output,o",
            boost::program_options::value<std::string>(),
            "file name to write results to"
        )
        (
            "threads,t",
            boost::program_options::value<uint>()->default_value(32),
            "number of threads to run in lock-step"
        )
        (
            "samples,s",
            boost::program_options::value<uint>()->default_value(131072),
            "number of samples to run"
        )
        (
            "smem",
            boost::program_options::value<uint>(),
            "bytes of shared memory to occupy per warp"
        )
        (
            "sync",
            "enable explicit warp synchronization"
        )
    ;

    boost::program_options::options_description opts_dist("distribution options");

    opts_dist.add_options()
        (
            "low",
            boost::program_options::value<uint>(),
            "lower bound for support (inclusive) (uniform)"
        )
        (
            "high",
            boost::program_options::value<uint>(),
            "upper bound for support (inclusive) (uniform)"
        )
        (
            "lambda",
            boost::program_options::value<float>(),
            "rate of events (poisson)"
        )
        (
            "probability",
            boost::program_options::value<float>(),
            "rate of events (binomial, geometric)"
        )
        (
            "trials",
            boost::program_options::value<uint>(),
            "rate of events (binomial)"
        )
        (
            "failures",
            boost::program_options::value<uint>(),
            "failure limit (nbinomial)"
        )
    ;

    opts.add(opts_dist);

    boost::program_options::options_description opts_dist_poisson("poisson distribution options");

    opts_dist_poisson.add_options()
    ;

    opts.add(opts_dist_poisson);

    boost::program_options::parsed_options parsed = boost::program_options::command_line_parser(
        argc, argv
    )
    .options(opts)
    .allow_unregistered()
    .run();

    boost::program_options::store(parsed, vm);

    if (vm.count("help")) {
        std::cout << opts << std::endl;
        std::exit(0);
    }

    try {
        boost::program_options::notify(vm);
    } catch (boost::program_options::required_option & e) {
        BOOST_LOG_TRIVIAL(error) << e.what();
        std::exit(1);
    }

    std::string dist = vm["distribution"].as<std::string>();

    if (dist == "uniform") {
        if (!vm.count("low")) {
            BOOST_LOG_TRIVIAL(error) << "Uniform distribution requires \"low\" to be specified";
            std::exit(1);
        }
        if (!vm.count("high")) {
            BOOST_LOG_TRIVIAL(error) << "Uniform distribution requires \"high\" to be specified";
            std::exit(1);
        }
    } else if (dist == "poisson") {
        if (!vm.count("lambda")) {
            BOOST_LOG_TRIVIAL(error) << "Poisson distribution requires \"lambda\" to be specified";
            std::exit(1);
        }
    } else if (dist == "geometric") {
        if (!vm.count("probability")) {
            BOOST_LOG_TRIVIAL(error) << "Geometric distribution requires \"probability\" to be specified";
            std::exit(1);
        }
    } else if (dist == "binomial") {
        if (!vm.count("probability")) {
            BOOST_LOG_TRIVIAL(error) << "Binomial distribution requires \"probability\" to be specified";
            std::exit(1);
        }
        if (!vm.count("trials")) {
            BOOST_LOG_TRIVIAL(error) << "Binomial distribution requires \"trials\" to be specified";
            std::exit(1);
        }
    } else if (dist == "nbinomial") {
        if (!vm.count("probability")) {
            BOOST_LOG_TRIVIAL(error) << "Negative binomial distribution requires \"probability\" to be specified";
            std::exit(1);
        }
        if (!vm.count("failures")) {
            BOOST_LOG_TRIVIAL(error) << "Negative binomial distribution requires \"failures\" to be specified";
            std::exit(1);
        }
    } else {
        BOOST_LOG_TRIVIAL(error) << "Invalid distribution \"" << dist << "\"";
        std::exit(1);
    }
}

int main(int argc, char* argv[]) {
    boost::program_options::variables_map vm;

    parse_opts(argc, argv, vm);

    std::mt19937::result_type seed;

    if (vm.count("seed")) {
        BOOST_LOG_TRIVIAL(info) << "Seeding randon number generator with user-provided seed";
        seed = vm["seed"].as<std::mt19937::result_type>();
    } else {
        BOOST_LOG_TRIVIAL(info) << "Seeding randon number generator with system-provided seed";
        std::random_device rd;
        seed = rd();
    }

    BOOST_LOG_TRIVIAL(info) << "Initializing Mersenne twister with seed " << seed;

    // std::random_device rd;
    std::mt19937 gen(seed);

    uint group_size = vm["threads"].as<uint>();
    uint group_count = vm["samples"].as<uint>();

    BOOST_LOG_TRIVIAL(info) << "Setting work group size to " << group_size;
    BOOST_LOG_TRIVIAL(info) << "Setting work set count to " << group_count;

    uint work_items = group_size * group_count;

    BOOST_LOG_TRIVIAL(info) << "Total number of work items is " << work_items;

    /*
    * Prepare the array of matrices.
    */
    BOOST_LOG_TRIVIAL(info) << "Preparing input matrices of size " << MAT_DIM << "x" << MAT_DIM;

    std::uniform_real_distribution<float> mdis(0.0f, 1.0f);
    float * _ms = new float[MAT_DIM * MAT_DIM * work_items];

    for (std::size_t i = 0; i < MAT_DIM * MAT_DIM * work_items; ++i) {
        _ms[i] = mdis(gen);
    }

    std::size_t input_matrix_bytes = MAT_DIM * MAT_DIM * work_items * sizeof(float);
    
    BOOST_LOG_TRIVIAL(info) << "Transfering input matrices to device (total size " << input_matrix_bytes << " bytes)";

    float * ms;

    cudaErrorCheck(cudaMalloc(&ms, input_matrix_bytes));
    cudaErrorCheck(cudaMemcpy(ms, _ms, input_matrix_bytes, cudaMemcpyHostToDevice));

    /*
     * Prepare the array of powers to which we raise our matrices.
     */
    BOOST_LOG_TRIVIAL(info) << "Preparing number of iterations per work item";

    uint * _ps = new uint[work_items];

    std::string dist = vm["distribution"].as<std::string>();

    if (dist == "uniform") {
        generate_ps<std::uniform_int_distribution>(_ps, work_items, gen, vm["low"].as<uint>(), vm["high"].as<uint>());
    } else if (dist == "poisson") {
        generate_ps<std::poisson_distribution>(_ps, work_items, gen, vm["lambda"].as<float>());
    } else if (dist == "geometric") {
        generate_ps<std::geometric_distribution>(_ps, work_items, gen, vm["probability"].as<float>());

        for (std::size_t i = 0; i < work_items; ++i) {
            _ps[i]++;
        }
    } else if (dist == "binomial") {
        generate_ps<std::binomial_distribution>(_ps, work_items, gen, vm["trials"].as<uint>(), vm["probability"].as<float>());
    } else if (dist == "nbinomial") {
        generate_ps<std::negative_binomial_distribution>(_ps, work_items, gen, vm["failures"].as<uint>(), vm["probability"].as<float>());
    }

    BOOST_LOG_TRIVIAL(info) << "Transfering iteration counts to device (total size " << (work_items * sizeof(uint)) << " bytes)";

    uint * ps;

    cudaErrorCheck(cudaMalloc(&ps, work_items * sizeof(uint)));
    cudaErrorCheck(cudaMemcpy(ps, _ps, work_items * sizeof(uint), cudaMemcpyHostToDevice));

    /*
     * Prepare the output arrays on the device.
     */
    float * os;
    uint * cs_simt, * cs_mimt;

    BOOST_LOG_TRIVIAL(info) << "Allocating memory for output matrices (total size " << (MAT_DIM * MAT_DIM * work_items * sizeof(float)) << " bytes)";

    cudaErrorCheck(cudaMalloc(&os, MAT_DIM * MAT_DIM * work_items * sizeof(float)));

    BOOST_LOG_TRIVIAL(info) << "Allocating memory for timing information (total size " << (2 * group_count * sizeof(uint)) << " bytes)";

    cudaErrorCheck(cudaMalloc(&cs_simt, group_count * sizeof(uint)));
    cudaErrorCheck(cudaMalloc(&cs_mimt, group_count * sizeof(uint)));

    /*
     * Prepare the output arrays on the host.
     */
    BOOST_LOG_TRIVIAL(info) << "Allocating host memory for output data";

    uint * _cs_simt = new uint[work_items];
    uint * _cs_mimt = new uint[work_items];

    /*
     * Run the SIMT simulation.
     */
    cudaErrorCheck(cudaDeviceSynchronize());

    int dev_id;
    cudaDeviceProp props;

    cudaErrorCheck(cudaGetDevice(&dev_id));
    cudaErrorCheck(cudaGetDeviceProperties(&props, dev_id));

    BOOST_LOG_TRIVIAL(info) << "Device info:";
    BOOST_LOG_TRIVIAL(info) << "    Name: " << props.name;
    BOOST_LOG_TRIVIAL(info) << "    Max shared memory per block: " << props.sharedMemPerBlockOptin << "B";
    BOOST_LOG_TRIVIAL(info) << "    CC version: " << props.major << "." << props.minor;

    uint smem_target;

    if (vm.count("smem")) {
        smem_target = vm["smem"].as<uint>();
    } else {
        smem_target = props.sharedMemPerBlockOptin;
    }

    if (smem_target > props.sharedMemPerBlock) {
        BOOST_LOG_TRIVIAL(info) << "Setting maximum shared memory to " << props.sharedMemPerBlockOptin << "B";

        cudaErrorCheck(cudaFuncSetAttribute(kernel<true>, cudaFuncAttributeMaxDynamicSharedMemorySize, props.sharedMemPerBlockOptin));
        cudaErrorCheck(cudaFuncSetAttribute(kernel<false>, cudaFuncAttributeMaxDynamicSharedMemorySize, props.sharedMemPerBlockOptin));
    }

    BOOST_LOG_TRIVIAL(info) << "Invoking kernel:";
    BOOST_LOG_TRIVIAL(info) << "    " << group_count << " blocks";
    BOOST_LOG_TRIVIAL(info) << "    " << WARP_SIZE << " threads per block";
    BOOST_LOG_TRIVIAL(info) << "    " << smem_target << " bytes of shared memory per block";

    if (vm.count("sync")) {
        BOOST_LOG_TRIVIAL(info) << "    Running in synchronized mode";
        kernel<true><<<group_count, WARP_SIZE, smem_target>>>(group_size, ms, os, ps, cs_simt, cs_mimt);
    } else {
        BOOST_LOG_TRIVIAL(info) << "    Running in unsynchronized mode";
        kernel<false><<<group_count, WARP_SIZE, smem_target>>>(group_size, ms, os, ps, cs_simt, cs_mimt);
    }
    
    cudaErrorCheck(cudaPeekAtLastError());

    BOOST_LOG_TRIVIAL(info) << "Awaiting kernel synchronization";

    cudaErrorCheck(cudaDeviceSynchronize());

    BOOST_LOG_TRIVIAL(info) << "Transfering results from device to host";

    cudaErrorCheck(cudaMemcpy(_cs_simt, cs_simt, group_count * sizeof(uint), cudaMemcpyDeviceToHost));
    cudaErrorCheck(cudaMemcpy(_cs_mimt, cs_mimt, group_count * sizeof(uint), cudaMemcpyDeviceToHost));

    cudaErrorCheck(cudaDeviceSynchronize());

    BOOST_LOG_TRIVIAL(info) << "Deallocating device memory";

    cudaErrorCheck(cudaFree(ms));
    cudaErrorCheck(cudaFree(ps));
    cudaErrorCheck(cudaFree(os));
    cudaErrorCheck(cudaFree(cs_simt));
    cudaErrorCheck(cudaFree(cs_mimt));

    BOOST_LOG_TRIVIAL(info) << "Results succesfully validated";

    std::string ofilename;

    if (vm.count("output")) {
        ofilename = vm["output"].as<std::string>();
    } else {
        std::stringstream ss;

        ss << "data_";

        if (dist == "uniform") {
            ss << "uniform_" << vm["low"].as<uint>() << "_" << vm["high"].as<uint>();
        } else if (dist == "poisson") {
            ss << "pois_" << vm["lambda"].as<float>();
        } else if (dist == "geometric") {
            ss << "geo_" << std::setfill('0') << std::setw(3) << static_cast<int>(100 * vm["probability"].as<float>());
        } else if (dist == "binomial") {
            ss << "binom_" << vm["trials"].as<uint>() << "_" << std::setfill('0') << std::setw(3) << static_cast<int>(100 * vm["probability"].as<float>());
        } else if (dist == "nbinomial") {
            ss << "nbinom_" << vm["failures"].as<uint>() << "_" << std::setfill('0') << std::setw(3) << static_cast<int>(100 * vm["probability"].as<float>());
        }

        ss << "_" << group_size << ".csv";

        ofilename = ss.str();
    }

    BOOST_LOG_TRIVIAL(info) << "Writing results to file " << ofilename;

    std::ofstream ofile;
    ofile.open(ofilename);

    ofile << "i,sim_simt,sim_mimt,mea_simt,mea_mimt" << std::endl;

    for (uint i = 0; i < group_count; ++i) {
        uint sum = 0;
        uint max = 0;

        for (uint j = 0; j < group_size; ++j) {
            max = std::max(max, _ps[i * group_size + j]);
            sum += _ps[i * group_size + j];
        }

        ofile << i << "," << (group_size * max) << "," << sum << "," << _cs_simt[i] << "," << _cs_mimt[i] << std::endl;
    }
    ofile.close();

    BOOST_LOG_TRIVIAL(info) << "Run complete, goodbye!";

    return 0;
}
