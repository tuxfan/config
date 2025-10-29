#------------------------------------------------------------------------------#
# CMakeLists.txt
#------------------------------------------------------------------------------#

cmake_minimum_required(VERSION 3.12)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

project(Test LANGUAGES CXX C)

set(CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(MFEM)

add_executable(test main.cc)
target_include_directories(test PUBLIC ${MFEM_INCLUDE_DIR})
target_link_libraries(test ${MFEM_LIBRARY})
