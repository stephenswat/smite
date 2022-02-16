project(DivergenceOverheadModelValidation)

cmake_minimum_required(VERSION 3.17)

enable_language(CUDA)

find_package(
    Boost
    1.65.0
    COMPONENTS
    program_options
    log_setup
    log
)

add_executable(
    generate
    main.cu
)

target_compile_options(
    generate
    PRIVATE
    $<$<COMPILE_LANGUAGE:CUDA>:
        --Werror all-warnings
        --compiler-options "-Wall -Wextra -Werror"
    >
)

target_link_libraries(
    generate
    PRIVATE
    Boost::program_options
    Boost::log_setup
    Boost::log
)

set_property(
    TARGET
    generate
    PROPERTY
    CUDA_STANDARD 17
)
