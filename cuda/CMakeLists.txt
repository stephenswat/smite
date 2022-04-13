project(DivergenceOverheadModelValidation)

cmake_minimum_required(VERSION 3.19)

enable_language(CUDA)

find_package(
    Boost
    1.71.0
    REQUIRED
    COMPONENTS
    log
    log_setup
    program_options
)

add_executable(
    generate
    main.cu
)

target_compile_options(
    generate
    PRIVATE
    $<$<COMPILE_LANGUAGE:CUDA>:
        -Wall
        --Werror all-warnings
        --compiler-options "-Wall -Wextra -Werror"
    >
)

target_link_libraries(
    generate
    PRIVATE
    Boost::log
    Boost::log_setup
    Boost::program_options
)

set_property(
    TARGET
    generate
    PROPERTY
    CUDA_STANDARD 17
)
