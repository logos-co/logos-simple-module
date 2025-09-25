if(NOT DEFINED GENERATOR OR GENERATOR STREQUAL "")
    message(STATUS "logos-cpp-generator not found; skipping generation for ${METADATA}")
    return()
endif()

if(NOT EXISTS "${GENERATOR}")
    message(WARNING "logos-cpp-generator path '${GENERATOR}' does not exist; skipping.")
    return()
endif()

set(_args --metadata "${METADATA}" --module-dir "${OUTPUT_DIR}")

message(STATUS "Running logos-cpp-generator on ${METADATA}")

execute_process(
    COMMAND "${GENERATOR}" ${_args}
    WORKING_DIRECTORY "${WORKING_DIRECTORY}"
    RESULT_VARIABLE _res
    OUTPUT_VARIABLE _stdout
    ERROR_VARIABLE _stderr
)

if(_res EQUAL 0)
    if(NOT _stdout STREQUAL "")
        string(REGEX REPLACE "\n$" "" _stdout "${_stdout}")
        message(STATUS "logos-cpp-generator output:\n${_stdout}")
    endif()
else()
    message(WARNING "logos-cpp-generator failed with exit code ${_res}; continuing without generated wrappers.")
    if(NOT _stderr STREQUAL "")
        string(REGEX REPLACE "\n$" "" _stderr "${_stderr}")
        message(WARNING "logos-cpp-generator stderr:\n${_stderr}")
    endif()
endif()
