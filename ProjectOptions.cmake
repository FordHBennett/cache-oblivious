include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(cache_oblivious_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(cache_oblivious_setup_options)
  option(cache_oblivious_ENABLE_HARDENING "Enable hardening" ON)
  option(cache_oblivious_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cache_oblivious_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cache_oblivious_ENABLE_HARDENING
    OFF)

  cache_oblivious_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cache_oblivious_PACKAGING_MAINTAINER_MODE)
    option(cache_oblivious_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cache_oblivious_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cache_oblivious_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cache_oblivious_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cache_oblivious_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cache_oblivious_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cache_oblivious_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cache_oblivious_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cache_oblivious_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cache_oblivious_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cache_oblivious_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cache_oblivious_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cache_oblivious_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cache_oblivious_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cache_oblivious_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cache_oblivious_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cache_oblivious_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cache_oblivious_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cache_oblivious_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cache_oblivious_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cache_oblivious_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cache_oblivious_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cache_oblivious_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cache_oblivious_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cache_oblivious_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cache_oblivious_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cache_oblivious_ENABLE_IPO
      cache_oblivious_WARNINGS_AS_ERRORS
      cache_oblivious_ENABLE_USER_LINKER
      cache_oblivious_ENABLE_SANITIZER_ADDRESS
      cache_oblivious_ENABLE_SANITIZER_LEAK
      cache_oblivious_ENABLE_SANITIZER_UNDEFINED
      cache_oblivious_ENABLE_SANITIZER_THREAD
      cache_oblivious_ENABLE_SANITIZER_MEMORY
      cache_oblivious_ENABLE_UNITY_BUILD
      cache_oblivious_ENABLE_CLANG_TIDY
      cache_oblivious_ENABLE_CPPCHECK
      cache_oblivious_ENABLE_COVERAGE
      cache_oblivious_ENABLE_PCH
      cache_oblivious_ENABLE_CACHE)
  endif()

  cache_oblivious_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cache_oblivious_ENABLE_SANITIZER_ADDRESS OR cache_oblivious_ENABLE_SANITIZER_THREAD OR cache_oblivious_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cache_oblivious_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cache_oblivious_global_options)
  if(cache_oblivious_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cache_oblivious_enable_ipo()
  endif()

  cache_oblivious_supports_sanitizers()

  if(cache_oblivious_ENABLE_HARDENING AND cache_oblivious_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cache_oblivious_ENABLE_SANITIZER_UNDEFINED
       OR cache_oblivious_ENABLE_SANITIZER_ADDRESS
       OR cache_oblivious_ENABLE_SANITIZER_THREAD
       OR cache_oblivious_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cache_oblivious_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cache_oblivious_ENABLE_SANITIZER_UNDEFINED}")
    cache_oblivious_enable_hardening(cache_oblivious_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cache_oblivious_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cache_oblivious_warnings INTERFACE)
  add_library(cache_oblivious_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cache_oblivious_set_project_warnings(
    cache_oblivious_warnings
    ${cache_oblivious_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(cache_oblivious_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    cache_oblivious_configure_linker(cache_oblivious_options)
  endif()

  include(cmake/Sanitizers.cmake)
  cache_oblivious_enable_sanitizers(
    cache_oblivious_options
    ${cache_oblivious_ENABLE_SANITIZER_ADDRESS}
    ${cache_oblivious_ENABLE_SANITIZER_LEAK}
    ${cache_oblivious_ENABLE_SANITIZER_UNDEFINED}
    ${cache_oblivious_ENABLE_SANITIZER_THREAD}
    ${cache_oblivious_ENABLE_SANITIZER_MEMORY})

  set_target_properties(cache_oblivious_options PROPERTIES UNITY_BUILD ${cache_oblivious_ENABLE_UNITY_BUILD})

  if(cache_oblivious_ENABLE_PCH)
    target_precompile_headers(
      cache_oblivious_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cache_oblivious_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cache_oblivious_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cache_oblivious_ENABLE_CLANG_TIDY)
    cache_oblivious_enable_clang_tidy(cache_oblivious_options ${cache_oblivious_WARNINGS_AS_ERRORS})
  endif()

  if(cache_oblivious_ENABLE_CPPCHECK)
    cache_oblivious_enable_cppcheck(${cache_oblivious_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cache_oblivious_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cache_oblivious_enable_coverage(cache_oblivious_options)
  endif()

  if(cache_oblivious_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cache_oblivious_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cache_oblivious_ENABLE_HARDENING AND NOT cache_oblivious_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cache_oblivious_ENABLE_SANITIZER_UNDEFINED
       OR cache_oblivious_ENABLE_SANITIZER_ADDRESS
       OR cache_oblivious_ENABLE_SANITIZER_THREAD
       OR cache_oblivious_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cache_oblivious_enable_hardening(cache_oblivious_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
